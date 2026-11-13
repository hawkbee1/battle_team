#!/usr/bin/env bash
# Rebuilds assets/3d_models/*.glb from assets_src/3d_models/ (POC streamed-world,
# step 2). One line per row of "Which model each element uses" in
# plan/poc/streamed-world.md. Needs only Node.
#
#   tool/models/build.sh
set -euo pipefail

cd "$(dirname "$0")"
[ -d node_modules ] || npm ci --silent

src=../../assets_src/3d_models
out=../../assets/3d_models

# lighten <output> <source folder> <budget kind> <lighten.mjs options...>
failed=0
lighten() {
  local name=$1 source=$2 kind=$3
  shift 3
  node lighten.mjs "$src/$source/scene.gltf" "$out/$name.glb" "$@"
  node inspect.mjs "$out/$name.glb" --budget "$kind" >/dev/null || {
    node inspect.mjs "$out/$name.glb" --budget "$kind" | grep OVER
    failed=1
  }
}

# Trees: both are already under 1,200 triangles, so only their textures change.
lighten tree_pine_near  stylized_pine_tree tree     --triangles 1200
lighten tree_flow_near  flow_tree          tree     --triangles 1200

# Infantry: the commander, and every infantry unit for now.
lighten infantry_near   soldier            infantry --triangles 3000
lighten infantry_far    soldier            infantry --triangles 150 --no-textures

# Vehicles: concept_tank, and hcr2_tank as the second candidate. Its tower and
# gun stay parts of their own.
lighten vehicle_near       concept_tank    vehicle  --triangles 3000
lighten vehicle_far        concept_tank    vehicle  --triangles 300 --no-textures
lighten vehicle_hcr2_near  hcr2_tank       vehicle  --triangles 3000 --no-textures \
  --keep-parts tower,gun

# HQ.
lighten hq_near         low_poly_building  hq       --triangles 3000

node inspect.mjs "$out"/*.glb
exit $failed
