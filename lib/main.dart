import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'services/api_service.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();

  ApiService.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'LudoSupreme Admin',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: (ApiService.token == null && !ApiService.demo)
          ? const LoginScreen()
          : const Shell(),
    );
  }
}
