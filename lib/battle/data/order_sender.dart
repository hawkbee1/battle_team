import 'package:battle_protocol/battle_protocol.dart';
import 'package:battle_team/battle/data/battle_repository.dart';
import 'package:logging/logging.dart';

/// Sends [order] named [name] through [repository] and logs it on [log]: sent,
/// then accepted, refused (warning, with the host's code) or failed (severe).
/// Completes with the host's refusal code, the error's text when the order
/// could not go out, or null when the host accepted it. Never a unit or a
/// position (decision 237).
Future<String?> sendOrder(
  Logger log,
  BattleRepository repository,
  String name,
  Order order,
) async {
  log.info('order $name sent');
  try {
    final refusal = await repository.send(order);
    if (refusal == null) {
      log.info('order $name accepted');
    } else {
      log.warning('order $name refused $refusal');
    }
    return refusal;
  } on Object catch (error, stackTrace) {
    log.severe('order $name failed', error, stackTrace);
    return '$error';
  }
}
