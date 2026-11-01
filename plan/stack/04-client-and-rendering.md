# Stack decision 4: client and 3D rendering

Status: **proposed** (milestone M2, Issue 4). Rules: decision 5 (top-down and first person); MAP-04; COMBAT-14 (aim in first person); decisions 3 and 4 (real time). Targets: iOS, Android, macOS, Windows, Linux and Web.

## What the rules require
- A **top-down camera** over a map of up to 10 × 50 km, and **first-person** control of one unit through its eyes (decision 5).
- Up to about 1,000 units on screen, with their visibility shown (fog per section).
- Six targets: iOS, Android, macOS, Windows, Linux and Web.
- The client shows the results of the rules; it never decides them (decision 3).

## Options
1. **Flame** (the current app dependency). A 2D engine. A top-down view can be drawn in 2D, but first person cannot. Rejected for the game world.
2. **flutter_scene** (3D on Flutter's GPU stack, with a WebGL2 backend for the web). Already a submodule of the workspace (`packages/flutter_scene`) and used by `dart_code_3d`. The same Dart code runs on all six targets, and Flutter widgets draw the interface on top.
3. **Unity or Godot.** Mature 3D on all targets, but a different language and toolchain. The Dart rules core would need a port or a bridge, which breaks stack decision 1. Rejected.
4. **A web 3D library inside a WebView** (for example three.js). One code path on Web, but separate paths on the other platforms, and a bridge for the interface. Rejected.

## Choice
**Option 2, flutter_scene**, for the world, the units and both camera modes. Flutter widgets for the interface: orders, map markers, team chat, alerts. Flame is not needed for the 3D game. Whether it stays in the app for other purposes is a question for M7.

## What flutter_scene provides (checked in `packages/flutter_scene`)
The formats and components below were read from the package's source and documentation on 2026-10-31. They are checked against the real code only when M7 starts.

**Platforms.** iOS, Android, macOS, Windows and Linux render through Impeller and Flutter GPU. Flutter GPU must be switched on once per platform (a plist key, a manifest entry, or the runner's `DartProject` setting). A **shipped** Windows or Linux build needs Flutter 3.47.1 or newer. The web uses a built-in WebGL2 backend, under both the CanvasKit and Skwasm renderers. Requires Flutter 3.47 stable.

**Asset formats.**
- **glTF**: `.glb` and multi-buffer `.gltf`. Two ways to load: at run time (`Node.fromGlbAsset`, `Node.fromGlbBytes`), which parses the file on every load; or at build time through a build hook, which converts it to the engine's binary scene format `.fsceneb`, loaded with `loadScene('assets/x.glb')`. For shipped assets the build-time route is the one the docs recommend.
- **`.fscene` / `.fsceneb`**: the scene document. Text (`.fscene`) and binary (`.fsceneb`) forms, with prefabs and declarative components.
- **Textures**: KTX2 with full mip chains, standard ETC1S builds through Basis Universal, `.fstex` builds, and `KHR_texture_basisu`.
- **Environments**: HDR and EXR images.
- **Custom materials**: `.fmat` files, written in GLSL, with hot reload.
- **Point clouds**: `.ply` and `.splat` (Gaussian splats). Not needed for the game.
- **Sparse accessors and `KHR_materials_variants`** are supported in glTF import; variants switch named material sets without duplicating materials.

**Components and classes that matter for Battle Team.**
- `Node` with `position`, `rotation` (a quaternion) and `scale`. Whole-value get and set; `frustumCulled` and `layers`.
- `Mesh`, `MeshGeometry` and `GeometryBuilder` for code-built meshes. Ten primitives, plus custom geometry.
- Index buffers are `Uint16List` **or** `Uint32List`. A terrain tile of 257 × 257 vertices has more than 65,535 vertices, so it needs `Uint32List` indices.
- `InstancedMesh` and `InstancedMeshComponent`: one geometry and material, many transforms, with per-instance colour. One cull test for the whole set. Instancing works for units that are static apart from their transform; a skinned, animated model is not instanced.
- `LodComponent` with `LodLevel`: swaps geometry by projected screen size. The shadow and depth passes always draw the highest detail, so LOD does not lighten shadow cost.
- `Animation`, `AnimationClip`, `AnimationPlayer`: keyframed animation, skinned glTF characters.
- `CameraComponent`, `NodeCamera` and camera controllers for the top-down and first-person cameras.
- `Light`: directional, point, spot and area lights. Shadows, ambient occlusion, reflections, fog, bloom and other post-processing exist, and can be switched off to save frame time.
- `TextureAtlas`, `MaterialsVariantsComponent`, `DecalNode`, particle emitters.
- Physics and audio are separate packages with their own backends (`scene` contract). They are not needed for the rules, which decide everything on the host.
- **There is no terrain component.** Terrain is a mesh built from a heightmap in code (`MeshGeometry`, as in the procedural skill), one tile at a time.

**Networking.** `flutter_scene_net` binds replicated state to the scene graph: replicas become nodes, and an interpolation buffer renders remote poses a fixed delay in the past. It builds on the `dashwire` multiplayer library. Its host (`SceneHost`) runs a WebSocket listener inside the app, is **native only**, and is a stub on the web. Relevant to M6; see `03-networking.md`.

**Performance tools.** The `flutter_scene-performance` skill gives the method: measure in profile mode, read the UI thread and the raster thread separately, then apply the fixes in a fixed order (instancing, LOD, culling, post-processing, materials, static shadows). `examples/stress_bench` runs synthetic scenes (10,000 items, 50,000 instances, churn) and prints the timings of each frame phase. It is the model for Battle Team's rendering benchmarks (`milestones/performance-tests.md`).

## Frame budget
Proposed, to confirm:
- Target: **60 frames per second** (16.6 ms per frame) on desktop targets. On phones and the web, the target is set after the spike (below).
- Split of the frame: state update from the network and render data up to 4 ms; world and unit rendering up to 10 ms; interface up to 2 ms.
- Units far from the camera use simplified meshes and instancing. Only the unit under first-person control uses full detail.

**The slowest target device is not known yet.** The designer does not know it either. The spike chooses it by measurement: three candidate devices per platform (for example a low-end phone, a laptop with an integrated GPU, and a web browser on that laptop). The slowest one measured becomes the reference for the budget. Until then, the phone and web budgets are open.

## Risks
- flutter_scene's performance with about 1,000 units on screen, on the slowest device and on the web, is **not measured**. This record does not claim a limit.
- The Flutter GPU switch and the 3.47.1 requirement for shipped desktop builds are constraints on the release process, not only on development.
- The first-person camera needs projectile visuals in 3D. The host traces each shot (decision 183, stack decision 8); the client only draws it.

## Consequences
- The client depends on `battle_rules` for display maths and on the network protocol (stack decision 3). It never runs its own combat resolution.
- The 3D code lives beside the app's Flame scaffold until M7 decides what stays.
- The spike is the first M7 task, so the choice can be reversed cheaply if it fails.
- Linux and macOS need their platform folders added to the app (the repository has `macos/` but no `linux/` yet). This is an M7 task.
