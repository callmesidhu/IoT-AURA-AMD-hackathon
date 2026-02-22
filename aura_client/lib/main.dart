import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'red_alert_screen.dart';
import 'main_navigation_screen.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: \${message.messageId}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint(
      "Firebase init failed (likely missing config). Continuing without Firebase.",
    );
  }

  runApp(const AuraApp());
}

class AuraApp extends StatefulWidget {
  const AuraApp({super.key});

  @override
  State<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends State<AuraApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  void _setupFCM() {
    try {
      // Request permission
      FirebaseMessaging.instance.requestPermission();

      // Handle message when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          "Foreground message received: \${message.notification?.title}",
        );
        if (message.data['action'] == 'FIRE_ALERT') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => RedAlertScreen(
                location: message.data['location'] ?? 'Unknown Location',
              ),
            ),
          );
        }
      });

      // Handle message when app is in background and user taps on it
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("Message clicked!");
        if (message.data['action'] == 'FIRE_ALERT') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => RedAlertScreen(
                location: message.data['location'] ?? 'Unknown Location',
              ),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint("FCM Setup failed: \$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: const Color(0xFF1B2333),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B2333),
          primary: const Color(0xFF1B2333),
          secondary: const Color(0xFFE94B4B),
        ),
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B2333),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1B2333)),
          ),
          hintStyle: const TextStyle(color: Color(0xFFA0AAB4)),
          prefixIconColor: const Color(0xFFA0AAB4),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const MainNavigationScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/alert': (context) =>
            const RedAlertScreen(location: 'MOCK LOCATION'), // fallback test
      },
    );
  }
}
