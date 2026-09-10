import 'package:flutter/material.dart';
import 'core/api/yobalema_api.dart';
import 'core/constants/yobalema_theme.dart';
import 'driver/screens/driver_auth_screen.dart';
import 'driver/screens/driver_main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YobalemaDriverApp());
}

class YobalemaDriverApp extends StatelessWidget {
  const YobalemaDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yobalema Chauffeur',
      debugShowCheckedModeBanner: false,
      theme: YobalemaTheme.lightTheme,
      home: const DriverRootFlow(),
    );
  }
}

class DriverRootFlow extends StatefulWidget {
  const DriverRootFlow({super.key});

  @override
  State<DriverRootFlow> createState() => _DriverRootFlowState();
}

class _DriverRootFlowState extends State<DriverRootFlow> {
  final api = YobalemaApi();
  Map<String, dynamic>? currentUser;
  bool checkingSession = true;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final session = await api.restoreSession(validate: true);
    if (mounted) {
      setState(() {
        if (session != null && session['role'] == 'DRIVER') {
          currentUser = session['user'];
        }
        checkingSession = false;
      });
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
      return DriverMainScreen(
        phone: currentUser!['phone']?.toString() ?? '',
        api: api,
        user: currentUser!,
        onLogout: () async {
          await api.clearSession();
          if (mounted) setState(() => currentUser = null);
        },
      );
    }

    return DriverAuthScreen(
      api: api,
      onAuthenticated: (user, token) {
        setState(() => currentUser = user);
      },
    );
  }
}
