import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/l10n/l10n.dart';
import 'package:battle_team/loading/loading.dart';
import 'package:flame/cache.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

class App extends StatelessWidget {
  const new({required this._backendStatusRepository, super.key});

  final BackendStatusRepository _backendStatusRepository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: _backendStatusRepository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) {
              final cubit = PreloadCubit(
                Images(prefix: ''),
                AudioCache(prefix: ''),
              );
              unawaited(cubit.loadSequentially());
              return cubit;
            },
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}

class AppView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2A48DF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A48DF),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        colorScheme: ColorScheme.fromSwatch(
          accentColor: const Color(0xFF2A48DF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2A48DF)),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoadingPage(),
    );
  }
}
