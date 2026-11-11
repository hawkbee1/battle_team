part of 'fog_cubit.dart';

/// {@template fog_state}
/// The ground the section sees: its [model], and a [revision] that grows each
/// time the ground in sight changes. View state: made from the section's own
/// units alone (decision 237), never sent, never logged.
/// {@endtemplate}
class FogState extends Equatable {
  /// {@macro fog_state}
  const new({required this.model, this.revision = 0});

  /// What the section knows of each cell of the ground (MAP-33).
  final FogModel model;

  /// Grows with each change of the ground in sight.
  final int revision;

  @override
  List<Object?> get props => [model, revision];
}
