import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/theme_provider.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screens.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/supabase_service.dart';
import 'widgets/app_widgets.dart';
import 'dart:async';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
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
              fontFamily: 'PlusJakartaSans',
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
              fontFamily: 'PlusJakartaSans',
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _user;
  bool _authKnown = false;
  bool _minSplashDone = false;
  StreamSubscription<User?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          _authKnown = true;
        });
      }
    });
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _minSplashDone = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authKnown || !_minSplashDone) {
      return const SplashScreen();
    }
    if (_user != null) {
      NotificationService().init(_user!.uid);
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}

/// Animated in-app splash shown briefly while the first auth event
/// arrives — a soft scale/fade of the logo on the brand gradient.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: kBrandGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.checklist_rtl, size: 48, color: Color(0xFF6D5DF6)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'TaskFlow',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Get things done, together.',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
