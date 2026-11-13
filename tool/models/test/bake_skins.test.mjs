import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Document } from '@gltf-transform/core';
import { prune } from '@gltf-transform/functions';
import { bakeSkins } from '../bake_skins.mjs';

const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];

/** One triangle skinned to `joints`, each weighted as `weights` says. */
function skinnedTriangle(joints, weights) {
  const document = new Document();
  const buffer = document.createBuffer();
  const scene = document.createScene();
  const accessor = (type, array) =>
    document.createAccessor().setType(type).setArray(array).setBuffer(buffer);
  const jointNodes = joints.map((translation, i) =>
    document.createNode(`joint${i}`).setTranslation(translation),
  );
  jointNodes.forEach((j) => scene.addChild(j));
  const skin = document
    .createSkin()
    .setInverseBindMatrices(
      accessor('MAT4', new Float32Array(jointNodes.length * 16).map((_, i) => identity[i % 16])),
    );
  jointNodes.forEach((j) => skin.addJoint(j));
  const w = weights.concat([0, 0, 0, 0]).slice(0, 4);
  const primitive = document
    .createPrimitive()
    .setAttribute('POSITION', accessor('VEC3', new Float32Array([0, 0, 0, 1, 0, 0, 0, 1, 0])))
    .setAttribute('NORMAL', accessor('VEC3', new Float32Array([0, 0, 1, 0, 0, 1, 0, 0, 1])))
    .setAttribute('JOINTS_0', accessor('VEC4', new Uint8Array([0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0])))
    .setAttribute('WEIGHTS_0', accessor('VEC4', new Float32Array([...w, ...w, ...w])));
  const node = document
    .createNode('body')
    .setMesh(document.createMesh().addPrimitive(primitive))
    .setSkin(skin)
    .setTranslation([9, 9, 9]); // ignored by a skinned mesh
  scene.addChild(node);

  const animation = document.createAnimation('walk');
  const sampler = document
    .createAnimationSampler()
    .setInput(accessor('SCALAR', new Float32Array([0, 1])))
    .setOutput(accessor('VEC3', new Float32Array([0, 0, 0, 0, 1, 0])));
  animation
    .addSampler(sampler)
    .addChannel(
      document
        .createAnimationChannel()
        .setSampler(sampler)
        .setTargetNode(jointNodes[0])
        .setTargetPath('translation'),
    );
  return { document, primitive, node };
}

test('a vertex follows its joint', () => {
  const { document, primitive } = skinnedTriangle([[0, 2, 0], [0, 0, 0]], [1]);
  bakeSkins(document);
  const position = primitive.getAttribute('POSITION');
  assert.deepEqual(Array.from(position.getArray()), [0, 2, 0, 1, 2, 0, 0, 3, 0]);
});

test('a vertex shared by two joints lands between them', () => {
  const { document, primitive } = skinnedTriangle([[0, 2, 0], [0, 0, 0]], [0.5, 0.5]);
  bakeSkins(document);
  const position = primitive.getAttribute('POSITION');
  assert.deepEqual(Array.from(position.getArray()), [0, 1, 0, 1, 1, 0, 0, 2, 0]);
});

test('the mesh ends static, at the scene, without its own transform', () => {
  const { document, primitive, node } = skinnedTriangle([[0, 2, 0], [0, 0, 0]], [1]);
  bakeSkins(document);
  assert.equal(node.getSkin(), null);
  assert.deepEqual(node.getTranslation(), [0, 0, 0]);
  assert.equal(document.getRoot().listScenes()[0].listChildren().includes(node), true);
  assert.equal(document.getRoot().listSkins().length, 0);
  assert.deepEqual(primitive.listSemantics().sort(), ['NORMAL', 'POSITION']);
});

test('no animation data survives pruning', async () => {
  const { document } = skinnedTriangle([[0, 2, 0], [0, 0, 0]], [1]);
  bakeSkins(document);
  await document.transform(prune());
  const root = document.getRoot();
  assert.equal(root.listAnimations().length, 0);
  assert.equal(root.listAccessors().length, 2); // position and normal
  assert.deepEqual(root.listNodes().map((n) => n.getName()), ['body']);
});
