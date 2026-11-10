import 'dart:async';
import 'dart:io';
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

/// A blue rifleman 5 m from the HQ, with 30 AP at 1 AP an hour and a loaded
/// rifle: it fires at [redSoldier], 135 m away, and may swap its weapon.
const blueRifleman = UnitView(
  unitId: 'u-1',
  unitType: 'soldier',
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: Position(50500, 6000, 3000),
  weapon: 'rifle',
  private: UnitPrivate(
    place: UnitPlace.deployed,
    ap: ApView(value: 30, at: Duration(hours: 1), perHour: 1, max: 30),
    morale: 100,
    rounds: 10,
    xpEarned: 0,
    xpUnspent: 0,
  ),
);

/// The blue section's artillery, 5 m from the HQ: it fires at positions.
const blueGun = UnitView(
  unitId: 'g-1',
  unitType: 'artillery',
  sectionId: 's-blue',
  team: 'blue',
  hp: 100,
  maxHp: 100,
  position: Position(50500, 6000, 3000),
  weapon: 'artillery',
  private: UnitPrivate(
    place: UnitPlace.deployed,
    ap: ApView(value: 30, at: Duration(hours: 1), perHour: 1, max: 30),
    morale: 100,
    rounds: 1,
    xpEarned: 0,
    xpUnspent: 0,
  ),
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

/// The blue section's whole view with an armed rifleman and a gun, and a
/// machine gun in the section's storage.
const armedView = SectionView(
  at: Duration(hours: 1),
  section: SectionPrivate(money: 0, xp: 0, storedWeapons: ['machine_gun']),
  units: [blueCommander, blueRifleman, blueGun, redSoldier],
  hqs: [
    HqView(
      team: 'blue',
      position: Position(50500, 5500, 3000),
      hp: 1000,
      maxHp: 1000,
    ),
  ],
  relics: [],
  world: [],
);

/// What a battle without test units lets a section buy, as the host lists it.
const shopRoster = Roster(
  units: [
    RosterUnit(
      unitType: 'soldier',
      category: 'soldier',
      price: 100,
      weapons: ['rifle', 'machine_gun', 'anti_tank', 'anti_air'],
    ),
    RosterUnit(unitType: 'radio', category: 'radio', price: 100),
    RosterUnit(
      unitType: 'jeep',
      category: 'vehicle',
      price: 1500,
      weapons: ['machine_gun'],
    ),
  ],
  weapons: [
    RosterWeapon(weapon: 'rifle', price: 100),
    RosterWeapon(weapon: 'machine_gun', price: 150),
    RosterWeapon(weapon: 'anti_tank', price: 400),
    RosterWeapon(weapon: 'anti_air', price: 300),
  ],
);

/// [shopRoster] in a battle that allows test units (UNIT-44).
const shopRosterWithTestUnit = Roster(
  units: [
    ...[
      RosterUnit(
        unitType: 'soldier',
        category: 'soldier',
        price: 100,
        weapons: ['rifle', 'machine_gun', 'anti_tank', 'anti_air'],
      ),
      RosterUnit(unitType: 'radio', category: 'radio', price: 100),
    ],
    RosterUnit(
      unitType: 'test_unit',
      category: 'soldier',
      price: 0,
      weapons: ['rifle', 'machine_gun'],
    ),
  ],
  weapons: [
    RosterWeapon(weapon: 'rifle', price: 100),
    RosterWeapon(weapon: 'machine_gun', price: 150),
  ],
);

/// A battle's host in memory: it signs the client in as the seat of [view]
/// (blue by default), sends [view], [roster] then [updates], answers each
/// command
/// ([refusal] refuses them, [silent] leaves them unanswered) and keeps their
/// orders.
final class FakeHost implements Transport {
  /// A host that shows [view].
  new({
    this.view = blueView,
    this.updates = const [],
    this.roster,
    this.accountId = 'bt-blue',
    this.sectionId = 's-blue',
    this.team = 'blue',
  });

  /// A host that plays the recorded stream [name] of `battle_client`'s
  /// fixtures (what `battle_host` really sent that section over a scripted
  /// battle): its whole view, then its updates.
  factory recorded(String name) {
    final messages = [
      for (final line in File(
        '../../packages/battle_client/test/fixtures/streams/$name.hex',
      ).readAsLinesSync())
        if (line.isNotEmpty) _codec.decodeHostMessage(_bytesOfHex(line)),
    ];
    final view = messages.first as SectionView;
    final own = view.units.firstWhere((unit) => unit.private != null);
    return FakeHost(
      view: view,
      updates: messages.skip(1).toList(),
      accountId: 'bt-${own.sectionId}',
      sectionId: own.sectionId,
      team: own.team,
    );
  }

  /// The section's whole view it sends.
  final SectionView view;

  /// What it sends after the whole view.
  final List<HostMessage> updates;

  /// What the battle lets the section buy, sent right after the whole view;
  /// none when null.
  final Roster? roster;

  /// The account, section and team it signs the client in as.
  final String accountId;
  final String sectionId;
  final String team;

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

Uint8List _bytesOfHex(String line) => Uint8List.fromList([
  for (var i = 0; i < line.length; i += 2)
    int.parse(line.substring(i, i + 2), radix: 16),
]);

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
          SignInAccepted(
            accountId: _host.accountId,
            sectionId: _host.sectionId,
            team: _host.team,
            battleTime: _host.view.at,
          ),
        );
        deliver(_host.view);
        if (_host.roster case final roster?) deliver(roster);
        _host.updates.forEach(deliver);
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
