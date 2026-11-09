import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';

const _codec = BinaryProtocolCodec();

/// The blue section's commander, with 30 AP at 1 AP an hour.
const blueCommander = UnitView(
  unitId: 'c-1',
  unitType: 'commander',
  sectionId: 's-blue',
  team: 'blue',
  hp: 200,
  maxHp: 200,
  position: Position(50500, 5500, 3000),
  private: UnitPrivate(
    place: UnitPlace.deployed,
    ap: ApView(value: 30, at: Duration(hours: 1), perHour: 1, max: 30),
    morale: 100,
    rounds: 10,
    xpEarned: 0,
    xpUnspent: 0,
  ),
);

/// A red soldier the blue section sees.
const redSoldier = UnitView(
  unitId: 'r-1',
  unitType: 'soldier',
  sectionId: 's-red',
  team: 'red',
  hp: 100,
  maxHp: 100,
  position: Position(50500, 20000, 3000),
);

/// A blue soldier in storage: no place on the map (HQ-33).
const storedSoldier = UnitView(
  unitId: 's-1',
  unitType: 'soldier',
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  private: UnitPrivate(
    place: UnitPlace.stored,
    ap: ApView(value: 30, at: Duration(hours: 1), perHour: 1, max: 30),
    morale: 100,
    rounds: 10,
    xpEarned: 0,
    xpUnspent: 0,
  ),
);

/// The blue section's whole view.
const blueView = SectionView(
  at: Duration(hours: 1),
  section: SectionPrivate(money: 0, xp: 0),
  units: [blueCommander, redSoldier],
  hqs: [
    HqView(
      team: 'blue',
      position: Position(50500, 5500, 3000),
      hp: 1000,
      maxHp: 1000,
    ),
  ],
  relics: [
    RelicView(relicId: 'relic-1', position: Position(20500, 30500, 3000)),
  ],
  world: [],
);

/// A battle's host in memory: it signs the client in as blue with
/// [view], answers each command ([refusal] refuses them, [silent] leaves
/// them unanswered) and keeps their orders.
final class FakeHost implements Transport {
  /// A host that shows [view].
  new({this.view = blueView});

  /// The section's view it sends.
  final SectionView view;

  /// The refusal of every command; null accepts them.
  String? refusal;

  /// Whether commands get no answer.
  bool silent = false;

  /// The orders it got.
  final orders = <Order>[];

  /// The sockets opened.
  final sockets = <FakeHostSocket>[];

  @override
  Future<TransportSocket> connect(Uri uri) async {
    final socket = FakeHostSocket(this);
    sockets.add(socket);
    return socket;
  }
}

/// One socket of a [FakeHost].
final class FakeHostSocket implements TransportSocket {
  new(this._host);

  final FakeHost _host;
  final _frames = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get frames => _frames.stream;

  /// Sends [message] to the client.
  void deliver(HostMessage message) =>
      scheduleMicrotask(() => _frames.add(_codec.encodeHostMessage(message)));

  @override
  void send(Uint8List frame) {
    switch (_codec.decodeClientMessage(frame)) {
      case SignIn():
        deliver(
          const SignInAccepted(
            accountId: 'bt-blue',
            sectionId: 's-blue',
            team: 'blue',
            battleTime: Duration(hours: 1),
          ),
        );
        deliver(_host.view);
      case SendCommand(:final requestId, :final command):
        _host.orders.add(command.order);
        if (_host.silent) return;
        deliver(switch (_host.refusal) {
          null => CommandAccepted(
            requestId: requestId,
            seq: _host.orders.length,
          ),
          final reason => CommandRefused(requestId: requestId, reason: reason),
        });
      case _:
        break;
    }
  }

  @override
  Future<void> close() async {
    if (!_frames.isClosed) await _frames.close();
  }
}

/// A client of [host], signing in with a JWT.
BattleClient fakeClient(
  FakeHost host, {
  Future<Uri> Function(Credential credential)? address,
}) => BattleClient(
  battleId: 'b-1',
  transport: host,
  address: address ?? (_) async => Uri.parse('ws://host/v1/socket'),
  credential: () async => const Credential.jwt('jwt'),
  clock: const SystemClock(),
  random: _Fixed(),
);

final class _Fixed implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 0;
}
