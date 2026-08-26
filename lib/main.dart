import 'package:flutter/material.dart';
import 'api.dart';
import 'models/models.dart';
import 'screens/auth/auth_home.dart';
import 'screens/driver/driver_screen.dart';
import 'screens/passenger/passenger_screen.dart';

export 'models/models.dart';
export 'screens/driver/driver_screen.dart';
export 'screens/passenger/passenger_screen.dart';
export 'services/routing_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YobalemaApp());
}

void openHomeScreen(
  BuildContext context, {
  required Map<String, dynamic> user,
  required String role,
  required YobalemaApi api,
}) {
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => HomeScreen(
        role: role.toUpperCase() == 'DRIVER' ? Role.driver : Role.passenger,
        phone: user['phone']?.toString() ?? '',
        api: api,
        user: Map<String, dynamic>.from(user),
      ),
    ),
    (route) => false,
  );
}

class YobalemaApp extends StatelessWidget {
  const YobalemaApp({super.key});

  static const yellow = Color(0xFFFFCC00);
  static const ink = Color(0xFF111111);
  static const grey = Color(0xFFF4F4F4);
  static const green = Color(0xFF159947);
  static const red = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yobalema',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: yellow,
          brightness: Brightness.light,
        ).copyWith(
          primary: ink,
          secondary: yellow,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: grey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: yellow, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: AuthHome(
        api: YobalemaApi(),
        onAuthenticated: (ctx, user, role, api) {
          openHomeScreen(ctx, user: user, role: role, api: api);
        },
      ),
    );
  }
}



class HomeScreen extends StatelessWidget {
  final Role role;
  final String phone;
  final YobalemaApi api;
  final Map<String, dynamic> user;

  const HomeScreen({
    super.key,
    required this.role,
    required this.phone,
    required this.api,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    if (role == Role.driver) {
      return DriverScreen(
        phone: phone,
        api: api,
        user: user,
      );
    }
    return PassengerScreen(
      phone: phone,
      api: api,
      user: user,
    );
  }
}
