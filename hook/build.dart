import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

/// Compiles the `.fmat` materials under `assets/` into
/// `flutter_scene_generated/`, where `loadFmatMaterial` finds them by their
/// source path (POC, branch poc/streamed-world: the ground's material). The
/// models stay `.glb` files read at run time, so `buildScenes` is not called.
void main(List<String> args) async {
  await build(args, (input, output) async {
    await buildMaterials(buildInput: input, buildOutput: output);
  });
}
