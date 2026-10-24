import 'dart:async';

import 'package:battle_team/backend_status/backend_status.dart';
import 'package:battle_team/game/game.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

class TitlePage extends StatelessWidget {
  const new({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const TitlePage());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) {
        final cubit = BackendStatusCubit(
          backendStatusRepository: context.read(),
        );
        unawaited(cubit.checkConnection());
        return cubit;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.titleAppBarTitle)),
        body: const SafeArea(child: TitleView()),
      ),
    );
  }
}

class TitleView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 250,
            height: 64,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.of(context)
                    .pushReplacement<void, void>(GamePage.route());
              },
              child: Center(child: Text(l10n.titleButtonStart)),
            ),
          ),
          const SizedBox(height: 24),
          const BackendStatusIndicator(),
        ],
      ),
    );
  }
}
