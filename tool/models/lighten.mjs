#!/usr/bin/env node
// Brings a downloaded glTF model down to a triangle and texture budget.
//
//   node lighten.mjs <in> <out> --triangles N [--no-textures] [--texture-size 256]
//                    [--error 1] [--keep-parts name,name]
//
// <in> is a .gltf or .glb, <out> a .glb. Both recipes end with a static model
// (a skinned source is baked in its rest pose and loses its skeleton and
// animations): the game draws models as instances, and a skinned model cannot
// be instanced (stack decision 4).
//
// With textures (near models): metalrough (flutter_scene does not read
// spec-gloss materials), weld, simplify, resize, prune, dedup. A textured
// material in alpha mode BLEND becomes MASK: cut-outs are not sorted, so they
// can be instanced.
//
// Without (far models): every vertex attribute but the position and every
// texture are dropped, then flatten, join, weld, simplify, normals, prune,
// dedup. The seams of UVs and normals are what stops the simplifier, so
// without them it goes much lower.
//
// --keep-parts names parts (case-insensitive, matched against the names of a
// mesh node and its ancestors) that join leaves as parts of their own, such as
// a tank's tower and gun; every other mesh of a no-texture model becomes one.
//
// The simplifier works per part. By default only the seams of a part stop it
// (--error 1 means no limit on the error), so the result can stay above
// --triangles; lower --error to keep the shape closer to the source.
import { statSync } from 'node:fs';
import { Logger } from '@gltf-transform/core';
import {
  dedup,
  flatten,
  join,
  metalRough,
  normals,
  prune,
  simplify,
  textureCompress,
  weld,
} from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';
import { bakeSkins } from './bake_skins.mjs';
import { countTriangles, makeIO, parseArgs } from './common.mjs';

const { positional, options } = parseArgs(process.argv.slice(2), [
  'no-textures',
]);
const [input, output] = positional;
const target = Number(options.triangles);
const textureSize = Number(options['texture-size'] ?? 256);
const error = Number(options.error ?? 1);
const noTextures = options['no-textures'] === true;
const keepParts = String(options['keep-parts'] ?? '')
  .split(',')
  .map((name) => name.trim().toLowerCase())
  .filter(Boolean);

if (!input || !output || !Number.isFinite(target) || target <= 0) {
  console.error(
    'usage: lighten.mjs <in> <out> --triangles N ' +
      '[--no-textures] [--texture-size 256] [--error 1] ' +
      '[--keep-parts name,name]',
  );
  process.exit(2);
}

const io = await makeIO();
const document = await io.read(input);
document.setLogger(new Logger(Logger.Verbosity.WARN));
const before = countTriangles(document);

bakeSkins(document);

if (noTextures) {
  dropEverythingButPositions(document);
  unifyMaterials(document);
  markKeptParts(document, keepParts);
  await document.transform(
    flatten(),
    join({ filter: (node) => !node.getExtras().keep }),
    weld(),
  );
  await simplifyTo(document, target, error);
  await document.transform(normals({ overwrite: true }), prune(), dedup());
} else {
  const specGloss = document
    .getRoot()
    .listExtensionsUsed()
    .some((e) => e.extensionName === 'KHR_materials_pbrSpecularGlossiness');
  if (specGloss) await document.transform(metalRough());
  await document.transform(weld());
  await simplifyTo(document, target, error);
  blendToMask(document);
  await document.transform(
    textureCompress({
      encoder: sharp,
      resize: [textureSize, textureSize],
    }),
    prune(),
    dedup(),
  );
}

await io.write(output, document);
console.log(
  `${output}: ${before} -> ${countTriangles(document)} triangles, ` +
    `${Math.round(statSync(output).size / 1000)} KB`,
);

/**
 * Each pass asks every part for the same ratio. A part that its seams keep
 * from going lower leaves the others to make up for it on the next pass.
 */
async function simplifyTo(doc, triangles, maxError) {
  let current = countTriangles(doc);
  for (let pass = 0; pass < 8 && current > triangles; pass++) {
    await doc.transform(
      simplify({
        simplifier: MeshoptSimplifier,
        ratio: triangles / current,
        error: maxError,
      }),
    );
    const next = countTriangles(doc);
    if (next >= current) return; // nothing left to take
    current = next;
  }
}

function dropEverythingButPositions(doc) {
  const root = doc.getRoot();
  for (const mesh of root.listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      for (const semantic of prim.listSemantics()) {
        if (semantic !== 'POSITION') prim.setAttribute(semantic, null);
      }
    }
  }
  for (const material of root.listMaterials()) {
    material
      .setBaseColorTexture(null)
      .setEmissiveTexture(null)
      .setNormalTexture(null)
      .setOcclusionTexture(null)
      .setMetallicRoughnessTexture(null);
  }
  for (const texture of root.listTextures()) texture.dispose();
}

function blendToMask(doc) {
  for (const material of doc.getRoot().listMaterials()) {
    if (material.getAlphaMode() === 'BLEND' && material.getBaseColorTexture()) {
      material.setAlphaMode('MASK').setAlphaCutoff(0.5);
    }
  }
}

/** Flags the mesh nodes that sit under a node named like one of `names`. */
function markKeptParts(doc, names) {
  if (names.length === 0) return;
  for (const node of doc.getRoot().listNodes()) {
    if (!node.getMesh()) continue;
    for (let n = node; n; n = n.getParentNode()) {
      const name = n.getName().toLowerCase();
      if (names.some((part) => name.includes(part))) {
        node.setExtras({ ...node.getExtras(), keep: true });
        break;
      }
    }
  }
}

/** One neutral material, so the far model is one part and one draw call. */
function unifyMaterials(doc) {
  const root = doc.getRoot();
  const material = doc
    .createMaterial('far')
    .setBaseColorFactor([1, 1, 1, 1])
    .setMetallicFactor(0)
    .setRoughnessFactor(1)
    .setAlphaMode('OPAQUE')
    .setDoubleSided(false);
  for (const mesh of root.listMeshes()) {
    for (const prim of mesh.listPrimitives()) prim.setMaterial(material);
  }
}
