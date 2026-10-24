import 'package:battle_team/game/game.dart';
import 'package:flame/components.dart';

class CounterComponent extends PositionComponent
    with HasGameReference<BattleTeam> {
  new({required super.position}) : super(anchor: Anchor.center);

  late final TextComponent text;

  @override
  Future<void> onLoad() async {
    await add(
      text = TextComponent(
        anchor: Anchor.bottomLeft,
        textRenderer: TextPaint(style: game.textStyle.copyWith(fontSize: 20)),
      ),
    );
  }

  @override
  void update(double dt) {
    text.text = game.l10n.counterText(game.counter);
  }
}
