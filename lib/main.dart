import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/session_controller.dart';
import 'controllers/timer_controller.dart';
import 'models.dart';
import 'theme/app_theme.dart';
import 'screens/lobby_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/game_screen.dart';
import 'screens/end_game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const YourTurnApp());
}

class YourTurnApp extends StatelessWidget {
  const YourTurnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionController()),
        ChangeNotifierProvider(create: (_) => TimerController()),
      ],
      child: MaterialApp(
        title: 'YourTurn',
        theme: AppTheme.buildTheme(),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Root screen that routes to the appropriate screen based on session state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final session = controller.session;

    // No session - show lobby
    if (session == null) {
      return const LobbyScreen();
    }

    // Route based on game phase
    switch (session.phase) {
      case GamePhase.setup:
        return const SetupScreen();
      case GamePhase.active:
        return const GameScreen();
      case GamePhase.ended:
        return const EndGameScreen();
    }
  }
}
