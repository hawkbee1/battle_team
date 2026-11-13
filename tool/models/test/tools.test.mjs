import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, before, test } from 'node:test';
import sharp from 'sharp';
import { countParts, countTriangles, makeIO, parseArgs } from '../common.mjs';
import { gridDocument } from './helpers.mjs';

const dir = mkdtempSync(join(tmpdir(), 'bt-models-'));
const lighten = new URL('../lighten.mjs', import.meta.url).pathname;
const inspect = new URL('../inspect.mjs', import.meta.url).pathname;
let io;
before(async () => {
  io = await makeIO();
});
after(() => rmSync(dir, { recursive: true, force: true }));

async function writeGrid(name, { texture = false, blend = false } = {}) {
  const { document, primitive } = gridDocument(30); // 1,800 triangles
  if (texture) {
    // Noise: prune swaps a single-colour texture for a colour factor.
    const png = await sharp({
      create: {
        width: 1024,
        height: 1024,
        channels: 3,
        background: '#808080',
        noise: { type: 'gaussian', mean: 128, sigma: 40 },
      },
    })
      .png()
      .toBuffer();
    const image = document
      .createTexture('color')
      .setImage(new Uint8Array(png))
      .setMimeType('image/png');
    const material = document.createMaterial('m').setBaseColorTexture(image);
    if (blend) material.setAlphaMode('BLEND');
    primitive.setMaterial(material);
  }
  const path = join(dir, name);
  await io.write(path, document);
  return path;
}

test('triangles are counted per instance of a mesh, parts per primitive', () => {
  const { document, mesh } = gridDocument(2); // 8 triangles
  document.getRoot().listScenes()[0].addChild(document.createNode('again').setMesh(mesh));
  assert.equal(countTriangles(document), 16);
  assert.equal(countParts(document), 2);
});

test('parseArgs keeps positionals, values and flags apart', () => {
  const { positional, options } = parseArgs(
    ['in.glb', '--triangles', '300', '--no-textures', 'out.glb', '--error=0.5'],
    ['no-textures'],
  );
  assert.deepEqual(positional, ['in.glb', 'out.glb']);
  assert.deepEqual(options, { triangles: '300', 'no-textures': true, error: '0.5' });
});

test('lighten: no-texture recipe keeps positions and normals, in the budget', async () => {
  const input = await writeGrid('in_far.glb', { texture: true });
  const output = join(dir, 'out_far.glb');
  execFileSync('node', [lighten, input, output, '--triangles', '300', '--no-textures']);
  const document = await io.read(output);
  const root = document.getRoot();
  assert.ok(countTriangles(document) <= 300, `${countTriangles(document)} triangles`);
  assert.equal(root.listTextures().length, 0);
  assert.equal(countParts(document), 1);
  const semantics = root.listMeshes()[0].listPrimitives()[0].listSemantics();
  assert.deepEqual(semantics.sort(), ['NORMAL', 'POSITION']);
});

test('lighten: texture recipe resizes textures and turns BLEND into MASK', async () => {
  const input = await writeGrid('in_near.glb', { texture: true, blend: true });
  const output = join(dir, 'out_near.glb');
  execFileSync('node', [lighten, input, output, '--triangles', '600']);
  const document = await io.read(output);
  const root = document.getRoot();
  assert.ok(countTriangles(document) <= 600);
  assert.deepEqual(root.listTextures()[0].getSize(), [256, 256]);
  assert.equal(root.listMaterials()[0].getAlphaMode(), 'MASK');
  assert.deepEqual(
    root.listMeshes()[0].listPrimitives()[0].listSemantics().sort(),
    ['NORMAL', 'POSITION', 'TEXCOORD_0'],
  );
});

test('lighten: a model already under the target is not simplified', async () => {
  const input = await writeGrid('in_small.glb');
  const output = join(dir, 'out_small.glb');
  execFileSync('node', [lighten, input, output, '--triangles', '5000']);
  assert.equal(countTriangles(await io.read(output)), 1800);
});

test('inspect: fails over the budget, passes inside it, far models take no texture', async () => {
  const big = await writeGrid('big.glb');
  const over = spawnSync('node', [inspect, big, '--budget', 'tree']);
  assert.equal(over.status, 1);
  assert.match(over.stdout.toString(), /OVER: 1800 triangles, near budget is 1200/);

  const small = join(dir, 'tree_ok.glb');
  execFileSync('node', [lighten, big, small, '--triangles', '1000']);
  assert.equal(spawnSync('node', [inspect, small, '--budget', 'tree']).status, 0);

  const textured = await writeGrid('veh_far.glb', { texture: true });
  const far = spawnSync('node', [inspect, textured, '--budget', 'vehicle']);
  assert.equal(far.status, 1);
  assert.match(far.stdout.toString(), /OVER: 1800 triangles, far budget is 300/);
  assert.match(far.stdout.toString(), /OVER: 1 textures on a far model/);
});
