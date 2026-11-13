// Bakes every skinned mesh of a document into plain geometry in the pose the
// file is saved in (no animation applied), then removes the skeleton.
//
// A skinned vertex is placed by sum(weight * jointWorld * inverseBind) and the
// transform of its own node is ignored, so the baked mesh moves under the
// scene with an identity transform.

export function bakeSkins(document) {
  const root = document.getRoot();
  const scene = root.getDefaultScene() ?? root.listScenes()[0];

  for (const node of root.listNodes()) {
    const skin = node.getSkin();
    const mesh = node.getMesh();
    if (!skin || !mesh) continue;
    if (mesh.listParents().filter((p) => p.propertyType === 'Node').length > 1) {
      throw new Error(`mesh "${mesh.getName()}" is shared by skinned nodes`);
    }

    const matrices = jointMatrices(skin);
    for (const prim of mesh.listPrimitives()) bakePrimitive(prim, matrices);

    node.setSkin(null);
    node.getParentNode()?.removeChild(node);
    scene.addChild(node);
    node.setTranslation([0, 0, 0]);
    node.setRotation([0, 0, 0, 1]);
    node.setScale([1, 1, 1]);
  }

  for (const skin of root.listSkins()) skin.dispose();
  // An animation keeps its keyframes and its target nodes alive until its
  // channels and samplers go too.
  for (const animation of root.listAnimations()) {
    animation.listChannels().forEach((channel) => channel.dispose());
    animation.listSamplers().forEach((sampler) => sampler.dispose());
    animation.dispose();
  }
}

function jointMatrices(skin) {
  const inverseBind = skin.getInverseBindMatrices();
  return skin.listJoints().map((joint, i) => {
    const ibm = new Array(16);
    if (inverseBind) {
      inverseBind.getElement(i, ibm);
    } else {
      ibm.splice(0, 16, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
    }
    return multiply(joint.getWorldMatrix(), ibm);
  });
}

function bakePrimitive(prim, matrices) {
  const position = prim.getAttribute('POSITION');
  const normal = prim.getAttribute('NORMAL');
  const tangent = prim.getAttribute('TANGENT');
  const sets = [];
  for (let k = 0; prim.getAttribute(`JOINTS_${k}`); k++) {
    sets.push([prim.getAttribute(`JOINTS_${k}`), prim.getAttribute(`WEIGHTS_${k}`)]);
  }
  if (sets.length === 0 || !position) return;

  const joints = new Array(4);
  const weights = new Array(4);
  const p = [0, 0, 0];
  const n = [0, 0, 0];
  const t = [0, 0, 0, 0];
  const blended = new Array(16);

  for (let v = 0; v < position.getCount(); v++) {
    blended.fill(0);
    for (const [jointAccessor, weightAccessor] of sets) {
      jointAccessor.getElement(v, joints);
      weightAccessor.getElement(v, weights);
      for (let c = 0; c < 4; c++) {
        const w = weights[c];
        if (w === 0) continue;
        const m = matrices[joints[c]];
        for (let i = 0; i < 16; i++) blended[i] += w * m[i];
      }
    }

    position.getElement(v, p);
    position.setElement(v, transformPoint(blended, p));
    if (normal) {
      normal.getElement(v, n);
      normal.setElement(v, normalize(transformDirection(blended, n)));
    }
    if (tangent) {
      tangent.getElement(v, t);
      const d = normalize(transformDirection(blended, t));
      tangent.setElement(v, [d[0], d[1], d[2], t[3]]);
    }
  }

  for (let k = 0; k < sets.length; k++) {
    prim.setAttribute(`JOINTS_${k}`, null);
    prim.setAttribute(`WEIGHTS_${k}`, null);
  }
}

// Column-major 4x4, as in glTF.
function multiply(a, b) {
  const out = new Array(16);
  for (let col = 0; col < 4; col++) {
    for (let row = 0; row < 4; row++) {
      let sum = 0;
      for (let k = 0; k < 4; k++) sum += a[k * 4 + row] * b[col * 4 + k];
      out[col * 4 + row] = sum;
    }
  }
  return out;
}

function transformPoint(m, [x, y, z]) {
  return [
    m[0] * x + m[4] * y + m[8] * z + m[12],
    m[1] * x + m[5] * y + m[9] * z + m[13],
    m[2] * x + m[6] * y + m[10] * z + m[14],
  ];
}

function transformDirection(m, [x, y, z]) {
  return [
    m[0] * x + m[4] * y + m[8] * z,
    m[1] * x + m[5] * y + m[9] * z,
    m[2] * x + m[6] * y + m[10] * z,
  ];
}

function normalize([x, y, z]) {
  const length = Math.hypot(x, y, z) || 1;
  return [x / length, y / length, z / length];
}
