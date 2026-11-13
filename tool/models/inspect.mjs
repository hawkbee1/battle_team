#!/usr/bin/env node
// Prints what a glTF/GLB costs to draw, and fails when it is over a budget.
//
//   node inspect.mjs <file>... [--budget tree|infantry|vehicle|hq]
//
// A file named *_far.* is checked against the far budget of the kind, any
// other file against the near budget. Budgets are the starting guesses of
// plan/poc/streamed-world.md.
import { readFileSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { getBounds } from '@gltf-transform/functions';
import { countParts, countTriangles, makeIO, parseArgs } from './common.mjs';

const BUDGETS = {
  tree: { near: 1200, far: 12, texture: 256, cutOutOnly: true },
  infantry: { near: 3000, far: 150, texture: 256 },
  vehicle: { near: 3000, far: 300, texture: 256 },
  hq: { near: 6000, far: null, texture: 256 },
};

const { positional: files, options } = parseArgs(process.argv.slice(2));
if (files.length === 0) {
  console.error(
    'usage: inspect.mjs <file>... [--budget tree|infantry|vehicle|hq]',
  );
  process.exit(2);
}
const budget = options.budget === undefined ? null : BUDGETS[options.budget];
if (options.budget !== undefined && !budget) {
  console.error(
    `unknown budget "${options.budget}" (${Object.keys(BUDGETS).join(', ')})`,
  );
  process.exit(2);
}

const io = await makeIO();
let failed = false;

for (const file of files) {
  const document = await io.read(file);
  const root = document.getRoot();

  const triangles = countTriangles(document);
  const parts = countParts(document);
  const materials = root.listMaterials();
  const alphaModes = [...new Set(materials.map((m) => m.getAlphaMode()))];
  const textures = root.listTextures();
  const sizes = textures.map((t) => t.getSize() ?? [0, 0]);
  const largest = sizes.reduce((max, [w, h]) => Math.max(max, w, h), 0);
  const extensions = root.listExtensionsUsed().map((e) => e.extensionName);
  const skins = root.listSkins().length;
  const animations = root.listAnimations().length;
  const attributes = new Set();
  for (const mesh of root.listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      for (const sem of prim.listSemantics()) attributes.add(sem);
    }
  }

  // Bounds ignore a skeleton: a skinned source is measured as its nodes sit.
  const scene = root.getDefaultScene() ?? root.listScenes()[0];
  const { min, max } = getBounds(scene);
  const dimensions = [0, 1, 2].map((i) => (max[i] - min[i]).toPrecision(3));

  console.log(file);
  console.log(
    `  triangles ${triangles.toLocaleString('en')}   parts ${parts}   ` +
      `size ${formatBytes(fileBytes(file))}   ` +
      `extent ${dimensions.join(' × ')} (x × y × z, model units)`,
  );
  console.log(
    `  materials ${materials.length} (alpha ${alphaModes.join(', ') || '-'})   ` +
      `textures ${textures.length}` +
      (textures.length > 0 ? ` (largest ${largest}², ${summary(sizes)})` : ''),
  );
  console.log(
    `  attributes ${[...attributes].join(' ')}   skins ${skins}   ` +
      `animations ${animations}   extensions ${extensions.join(', ') || '-'}`,
  );

  if (budget) {
    const far = /_far\.[^.]+$/.test(file);
    const problems = [];
    const limit = far ? budget.far : budget.near;
    if (limit === null) {
      problems.push(`the ${options.budget} has no far model`);
    } else if (triangles > limit) {
      problems.push(
        `${triangles} triangles, ${far ? 'far' : 'near'} budget is ${limit}`,
      );
    }
    if (far && textures.length > 0) {
      problems.push(`${textures.length} textures on a far model`);
    }
    if (!far && largest > budget.texture) {
      problems.push(`a ${largest}² texture, budget is ${budget.texture}²`);
    }
    if (alphaModes.includes('BLEND')) {
      problems.push('alpha mode BLEND (use MASK or OPAQUE)');
    }
    if (skins > 0) {
      problems.push('a skeleton: a skinned model cannot be instanced');
    }
    if (problems.length === 0) {
      console.log(`  within the ${options.budget} budget`);
    } else {
      failed = true;
      for (const problem of problems) console.log(`  OVER: ${problem}`);
    }
  }
}

process.exit(failed ? 1 : 0);

function summary(sizes) {
  const counts = new Map();
  for (const [w, h] of sizes) {
    const key = `${w}²`;
    counts.set(key, (counts.get(key) ?? 0) + (w === h ? 1 : 0));
    if (w !== h) counts.set(`${w}×${h}`, (counts.get(`${w}×${h}`) ?? 0) + 1);
  }
  return [...counts].map(([k, n]) => `${n}×${k}`).join(' ');
}

/** A .glb is one file; a .gltf adds its .bin buffers and images. */
function fileBytes(file) {
  const bytes = statSync(file).size;
  if (!file.endsWith('.gltf')) return bytes;
  const json = JSON.parse(readFileSync(file, 'utf8'));
  const dir = dirname(resolve(file));
  let total = bytes;
  for (const entry of [...(json.buffers ?? []), ...(json.images ?? [])]) {
    if (entry.uri && !entry.uri.startsWith('data:')) {
      total += statSync(resolve(dir, decodeURIComponent(entry.uri))).size;
    }
  }
  return total;
}

function formatBytes(bytes) {
  return bytes >= 1_000_000
    ? `${(bytes / 1_000_000).toFixed(1)} MB`
    : `${Math.round(bytes / 1000)} KB`;
}
