import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/theme_provider.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screens.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Add dummy users for testing purposes
  try {
    await DatabaseService().addDummyUsers();
  } catch (e) {
    print('Failed to add dummy users: $e');
  }
  
  runApp(const TaskFlowApp());
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
        StreamProvider<User?>(
          create: (context) => Provider.of<AuthService>(context, listen: false).user,
          initialData: null,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'TaskFlow',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            navigatorKey: navigatorKey,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6C63FF),
                primary: const Color(0xFF6C63FF),
                surface: const Color(0xFFF7F8FA),
              ),
              useMaterial3: true,
              textTheme: GoogleFonts.interTextTheme(),
              scaffoldBackgroundColor: const Color(0xFFF7F8FA),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF6C63FF),
                secondary: Color(0xFF3B33FF),
                surface: Color(0xFF121212),
                background: Colors.black,
              ),
              cardColor: const Color(0xFF1E1E1E),
              useMaterial3: true,
              textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthWrapper(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    if (user != null) {
      NotificationService().init(user.uid);
      return const HomeScreen();
    } else {
      // In a real app, you might check if onboarding was seen
      return const OnboardingScreen();
    }
  }
}
