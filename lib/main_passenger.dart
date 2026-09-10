import 'package:flutter/material.dart';
import 'core/api/yobalema_api.dart';
import 'core/constants/yobalema_theme.dart';
import 'passenger/screens/passenger_auth_screen.dart';
import 'passenger/screens/passenger_main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YobalemaPassengerApp());
}

class YobalemaPassengerApp extends StatelessWidget {
  const YobalemaPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yobalema Passager',
      debugShowCheckedModeBanner: false,
      theme: YobalemaTheme.lightTheme,
      home: const PassengerRootFlow(),
    );
  }
}

class PassengerRootFlow extends StatefulWidget {
  const PassengerRootFlow({super.key});

  @override
  State<PassengerRootFlow> createState() => _PassengerRootFlowState();
}

class _PassengerRootFlowState extends State<PassengerRootFlow> {
  final api = YobalemaApi();
  Map<String, dynamic>? currentUser;
  bool checkingSession = true;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    try {
      final session = await api.restoreSession(validate: true);
      if (mounted) {
        setState(() {
          if (session != null && session['role'] == 'PASSENGER') {
            final user = session['user'];
            if (user is Map<String, dynamic>) {
              currentUser = user;
            } else if (user is Map) {
              currentUser = Map<String, dynamic>.from(user);
            }
          }
          checkingSession = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          checkingSession = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checkingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: YobalemaTheme.ink),
        ),
      );
    }

    if (currentUser != null) {
      return PassengerMainScreen(
        phone: currentUser!['phone']?.toString() ?? '',
        api: api,
        user: currentUser!,
        onLogout: () async {
          await api.clearSession();
          if (mounted) setState(() => currentUser = null);
        },
      );
    }

    return PassengerAuthScreen(
      api: api,
      onAuthenticated: (user, token) {
        setState(() => currentUser = user);
      },
    );
  }
}
