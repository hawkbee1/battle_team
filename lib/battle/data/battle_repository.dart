import 'dart:math' as math;

import 'package:appwrite_api_client/appwrite_api_client.dart';
import 'package:battle_client/battle_client.dart';
import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/battle_settings.dart';
import 'package:battle_team/battle/data/battle_snapshot.dart';
import 'package:battle_team/battle/data/connection_status.dart';

/// {@template battle_repository}
/// The data the battle screen lives on, for one battle: it signs the player
/// in to Appwrite, builds the `BattleClient` that finds the battle's host
/// with a fresh JWT each time and keeps the section's view, and shows the
/// screen what it needs of both: [connection], [snapshots], the host's
/// answers to [send], the battle time and the AP between updates. The cubit
/// above it never sees the client (Adapter over `battle_client` and
/// `appwrite_api_client`).
///
/// The host checks every order (decision 3, stack decision 8): the
/// repository checks nothing. A repository serves one session: [start] it
/// once, [close] it when the screen goes.
/// {@endtemplate}
class BattleRepository {
  /// {@macro battle_repository}
  ///
  /// [transport], [address], [clock] and [random] are the ports of the
  /// client; tests replace them. By default the host's address comes from
  /// Appwrite's `bt_battle_host` function.
  new({
    required BattleSettings settings,
    required AppwriteApiClient apiClient,
    Transport transport = const WebSocketTransport(),
    Future<Uri> Function(Credential credential)? address,
    Clock clock = const SystemClock(),
    math.Random? random,
  }) : _settings = settings,
       _apiClient = apiClient,
       _client = BattleClient(
         battleId: settings.battleId,
         transport: transport,
         address: address ?? _hostAddress(settings),
         credential: () async => Credential.jwt(await apiClient.createJwt()),
         clock: clock,
         random: random ?? math.Random.secure(),
       );

  final BattleSettings _settings;
  final AppwriteApiClient _apiClient;
  final BattleClient _client;

  static Future<Uri> Function(Credential credential) _hostAddress(
    BattleSettings settings,
  ) {
    final finder = AppwriteHostFinder(
      endpoint: Uri.parse(settings.endpoint),
      project: settings.projectId,
    );
    return (credential) => finder.socketOf(settings.battleId, credential);
  }

  /// Whether every setting of the battle was given.
  bool get isConfigured => _settings.complete;

  /// The battle's map, in the app's assets.
  String get mapId => _settings.mapId;

  /// Signs the player in to Appwrite, so that the client gets JWTs.
  ///
  /// Throws an [AppwriteSignInFailure] when it cannot.
  Future<void> signIn() =>
      _apiClient.signIn(email: _settings.email, password: _settings.password);

  /// Each change of [connection]'s status, from the next one on.
  Stream<ConnectionStatus> get connection => _client.statuses.map(
    (status) => switch (status) {
      ClientStatus.idle ||
      ClientStatus.connecting => ConnectionStatus.connecting,
      ClientStatus.signedIn => ConnectionStatus.connected,
      ClientStatus.waiting => ConnectionStatus.lost,
      ClientStatus.stopped => ConnectionStatus.stopped,
    },
  );

  /// The section's view after each message of the host.
  Stream<BattleSnapshot> get snapshots => _client.messages.map((_) {
    final view = _client.view;
    final seat = _client.seat;
    return BattleSnapshot(
      units: Map.of(view.units),
      hqs: view.hqs.values.toList(),
      relics: view.relics.values.toList(),
      team: seat?.team,
      sectionId: seat?.sectionId,
    );
  });

  /// Why the connection stopped for good: the host's last word or the
  /// lasting refusal to give its address. Null while it runs, and when the
  /// repository itself was closed.
  String? get stopReason =>
      switch ((_client.stoppedBy, _client.lookupRefused)) {
        (final HostMessage message?, _) => '$message',
        (_, final HostLookupException refused?) => refused.code,
        _ => null,
      };

  /// The battle time now, as the client shows it; null before the host's
  /// first message.
  Duration? get battleTime => _client.battleTime;

  /// The AP of [ap] now, between the host's updates (stack decision 8).
  double? apNow(ApView ap) => _client.apNow(ap);

  /// Connects: finds the host, signs in to it and keeps the view until the
  /// connection stops. Listen to [connection] and [snapshots] first.
  void start() => _client.start();

  /// Sends [order]; completes with the host's refusal code, or null when
  /// the host accepted it.
  ///
  /// Throws when the connection never signed in or has stopped.
  Future<String?> send(Order order) async =>
      (await _client.send(order)).refusal;

  /// Stops for good; an order still unanswered fails.
  Future<void> close() => _client.close();
}
