import { Document } from '@gltf-transform/core';

/** A bumpy grid of n × n quads (2n² triangles) with normals and UVs. */
export function gridDocument(n) {
  const document = new Document();
  const buffer = document.createBuffer();
  const positions = [];
  const normals = [];
  const uvs = [];
  for (let y = 0; y <= n; y++) {
    for (let x = 0; x <= n; x++) {
      positions.push(x / n, y / n, 0.2 * Math.sin((x * y) / n));
      normals.push(0, 0, 1);
      uvs.push(x / n, y / n);
    }
  }
  const indices = [];
  for (let y = 0; y < n; y++) {
    for (let x = 0; x < n; x++) {
      const a = y * (n + 1) + x;
      indices.push(a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1);
    }
  }
  const accessor = (type, array) =>
    document.createAccessor().setType(type).setArray(array).setBuffer(buffer);
  const primitive = document
    .createPrimitive()
    .setIndices(accessor('SCALAR', new Uint16Array(indices)))
    .setAttribute('POSITION', accessor('VEC3', new Float32Array(positions)))
    .setAttribute('NORMAL', accessor('VEC3', new Float32Array(normals)))
    .setAttribute('TEXCOORD_0', accessor('VEC2', new Float32Array(uvs)));
  const mesh = document.createMesh('grid').addPrimitive(primitive);
  const node = document.createNode('grid').setMesh(mesh);
  document.createScene().addChild(node);
  return { document, buffer, primitive, mesh, node };
}
