import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/theme_provider.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screens.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  await SupabaseService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Set system UI style for full screen / edge-to-edge look
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark, // Default, will be updated by theme
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // Add dummy users for testing purposes without blocking app launch
  DatabaseService().addDummyUsers().catchError((e) {
    print('Failed to add dummy users: $e');
  });
  
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
              fontFamily: '.SF Pro Display', // Fallback to system native on iOS
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF5B5BF7),
                primary: const Color(0xFF5B5BF7),
                secondary: const Color(0xFF5B5BF7),
                surface: const Color(0xFFFFFFFF),
                background: const Color(0xFFFFFFFF),
                onBackground: const Color(0xFF1A1A1A),
                onSurface: const Color(0xFF1A1A1A),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFFFFFFF),
              dividerColor: const Color(0xFFECECEC),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              fontFamily: '.SF Pro Display',
              scaffoldBackgroundColor: const Color(0xFF0A0A0C),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF5B5BF7),
                secondary: Color(0xFF5B5BF7),
                surface: Color(0xFF16161A),
                background: Color(0xFF0A0A0C),
                onBackground: Colors.white,
                onSurface: Colors.white,
              ),
              dividerColor: const Color(0xFF2C2C2E),
              cardColor: const Color(0xFF16161A),
              useMaterial3: true,
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthWrapper(),
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
      return const LoginScreen();
    }
  }
}
