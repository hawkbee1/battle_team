// Shared by lighten.mjs and inspect.mjs (POC streamed-world, step 2).
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { MeshoptDecoder, MeshoptEncoder } from 'meshoptimizer';

export async function makeIO() {
  await MeshoptDecoder.ready;
  await MeshoptEncoder.ready;
  return new NodeIO()
    .registerExtensions(ALL_EXTENSIONS)
    .registerDependencies({
      'meshopt.decoder': MeshoptDecoder,
      'meshopt.encoder': MeshoptEncoder,
    });
}

/** Triangles drawn by the default scene: one count per mesh instance. */
export function countTriangles(document) {
  let triangles = 0;
  for (const node of sceneNodes(document)) {
    const mesh = node.getMesh();
    if (!mesh) continue;
    for (const prim of mesh.listPrimitives()) {
      triangles += primitiveTriangles(prim);
    }
  }
  return triangles;
}

/** Primitives drawn by the default scene (each one is a draw call). */
export function countParts(document) {
  let parts = 0;
  for (const node of sceneNodes(document)) {
    const mesh = node.getMesh();
    if (mesh) parts += mesh.listPrimitives().length;
  }
  return parts;
}

export function primitiveTriangles(prim) {
  const indices = prim.getIndices();
  const count = indices
    ? indices.getCount()
    : (prim.getAttribute('POSITION')?.getCount() ?? 0);
  switch (prim.getMode()) {
    case 4: // TRIANGLES
      return Math.floor(count / 3);
    case 5: // TRIANGLE_STRIP
    case 6: // TRIANGLE_FAN
      return Math.max(0, count - 2);
    default:
      return 0; // points and lines draw no triangle
  }
}

function sceneNodes(document) {
  const root = document.getRoot();
  const scene = root.getDefaultScene() ?? root.listScenes()[0];
  const nodes = [];
  scene?.traverse((node) => nodes.push(node));
  return nodes;
}

/** `flags` are the options that take no value. */
export function parseArgs(argv, flags = []) {
  const positional = [];
  const options = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) {
      positional.push(arg);
      continue;
    }
    const [key, inline] = arg.slice(2).split('=');
    const next = argv[i + 1];
    if (inline !== undefined) {
      options[key] = inline;
    } else if (flags.includes(key)) {
      options[key] = true;
    } else if (next !== undefined && !next.startsWith('--')) {
      options[key] = next;
      i++;
    } else {
      options[key] = true;
    }
  }
  return { positional, options };
}
