import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../models/app_models.dart';
import "../screens/task_detail_screen.dart";

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // init() is called from AuthWrapper.build(), which can rebuild often.
  // Guard so FCM listeners are only ever registered once per user.
  static bool _initialized = false;
  static String? _initializedUid;

  Future<void> init(String uid) async {
    if (_initialized && _initializedUid == uid) return;
    _initialized = true;
    _initializedUid = uid;

    // Request permissions for iOS and Android 13+
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
      
      // Get the token
      String? token = await _fcm.getToken();
      if (token != null) {
        // Save to Firestore
        await _db.collection('users').doc(uid).update({'fcmToken': token});
      }

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _db.collection('users').doc(uid).update({'fcmToken': newToken});
      });

      // Initialize local notifications for foreground
      _initLocalNotifications();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          _showLocalNotification(message);
        }
      });

      // Handle click on background notifications
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      // Handle click on terminated app notifications
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }
    }
  }

  void _handleMessage(RemoteMessage message) async {
    final taskId = message.data['taskId'];
    if (taskId != null) {
      try {
        final doc = await _db.collection('tasks').doc(taskId).get();
        if (doc.exists && navigatorKey.currentContext != null) {
          final task = TaskModel.fromFirestore(doc);
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
          );
        }
      } catch (e) {
        debugPrint('Error handling deep link: $e');
      }
    }
  }

  void _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _localNotifications.initialize(initSettings);
  }

  void _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Task Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }
}
