import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';
import 'supabase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In...');
      // Add a timeout to avoid hanging forever
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Google Sign-In timed out');
          throw Exception('Sign-in timed out. Please try again.');
        },
      );

      if (googleUser == null) {
        debugPrint('Google Sign-In canceled by user');
        return null;
      }

      debugPrint('Google Sign-In successful, getting authentication...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Authenticating with Firebase...');
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Save user to Firestore
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? 'Unknown',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'lastSeen': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
        debugPrint('User saved to Firestore: ${user.uid}');
      }

      return user;
    } catch (e) {
      debugPrint('--- GOOGLE SIGN-IN ERROR ---');
      debugPrint('Type: ${e.runtimeType}');
      debugPrint('Details: $e');
      if (e.toString().contains('10')) {
        debugPrint('SUGGESTION: Error 10 usually means the SHA-1 is missing in Firebase or the Support Email is not set.');
      }
      rethrow; // Rethrow so the UI can catch it and show a Snackbar
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      debugPrint('Email Sign-In Error: $e');
      rethrow;
    }
  }

  Future<User?> registerWithEmail(String email, String password, String name) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'photoUrl': 'https://api.dicebear.com/7.x/initials/png?seed=$name',
          'lastSeen': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
      return user;
    } catch (e) {
      debugPrint('Email Registration Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;

  // Stream of tasks assigned to or by the user
  Future<TaskModel?> getTaskById(String taskId) async {
    final doc = await _db.collection('tasks').doc(taskId).get();
    if (doc.exists) {
      return TaskModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<List<TaskModel>> getTasks(String uid) {
    return _db.collection('tasks')
        .where(Filter.or(
          Filter('assignedTo', isEqualTo: uid),
          Filter('assignedBy', isEqualTo: uid),
        ))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList());
  }

  /// Stream of every task in the team (read is team-wide, see
  /// firestore.rules). Used by the Team screen so member counts come
  /// from ONE stream instead of one stream per member row.
  Stream<List<TaskModel>> getAllTasks() {
    return _db.collection('tasks')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromFirestore(doc))
            .toList());
  }

  // Stream of all users for assignment
  Stream<List<AppUser>> getAllUsers() {
    return _db.collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromMap(doc.data()))
            .toList());
  }

  Future<void> createTask(TaskModel task) async {
    final docRef = await _db.collection('tasks').add(task.toMap()).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Could not connect to database. Did you create a Firestore Database in the Firebase Console?'),
    );
    
    // Save the in-app notification — the sendPushOnNotification Cloud
    // Function turns this document into the FCM push automatically.
    saveNotification(
      recipientUid: task.assignedTo,
      title: 'New Task Assigned 📋',
      body: '${user?.displayName ?? "Someone"} assigned: ${task.title}',
      senderPhoto: user?.photoURL,
      data: {
        'type': 'NEW_TASK',
        'taskId': docRef.id,
      },
    );
  }

  Future<void> updateTaskDetails(String taskId, String title, String description, String category, String priority, DateTime deadline, {String? imageUrl, String? audioUrl}) async {
    final Map<String, dynamic> updateData = {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'deadline': Timestamp.fromDate(deadline),
      'updatedAt': Timestamp.now(),
    };
    if (imageUrl != null) updateData['imageUrl'] = imageUrl;
    if (audioUrl != null) updateData['audioUrl'] = audioUrl;

    await _db.collection('tasks').doc(taskId).update(updateData);
  }

  /// Sets the workflow status (TaskStatus.todo / inProgress / done).
  /// `isDone` is kept in sync for backward compatibility with older
  /// builds and with queries that filter on it.
  Future<void> setTaskStatus(String taskId, String status, {String? taskTitle, String? assignedBy}) async {
    final isDone = status == TaskStatus.done;
    await _db.collection('tasks').doc(taskId).update({
      'status': status,
      'isDone': isDone,
      'statusUpdatedAt': Timestamp.now(),
    });
    final user = _auth.currentUser;

    // Recurring task: spawn the next occurrence exactly once.
    if (status == TaskStatus.done) {
      try {
        final doc = await _db.collection('tasks').doc(taskId).get();
        final data = doc.data();
        final recurrence = data?['recurrence'] as String?;
        if (data != null && recurrence != null && recurrence != 'none' && data['nextSpawned'] != true) {
          await _db.collection('tasks').doc(taskId).update({'nextSpawned': true});
          final oldDeadline = (data['deadline'] as Timestamp).toDate();
          DateTime next;
          switch (recurrence) {
            case 'daily':
              next = oldDeadline.add(const Duration(days: 1));
              break;
            case 'weekly':
              next = oldDeadline.add(const Duration(days: 7));
              break;
            case 'monthly':
              final month = oldDeadline.month == 12 ? 1 : oldDeadline.month + 1;
              final year = oldDeadline.month == 12 ? oldDeadline.year + 1 : oldDeadline.year;
              final day = oldDeadline.day > 28 ? 28 : oldDeadline.day;
              next = DateTime(year, month, day, oldDeadline.hour, oldDeadline.minute);
              break;
            default:
              next = oldDeadline;
          }
          // If the next occurrence is already past, roll it forward to today.
          final now = DateTime.now();
          if (next.isBefore(now)) {
            next = DateTime(now.year, now.month, now.day, oldDeadline.hour, oldDeadline.minute);
            if (next.isBefore(now)) next = next.add(const Duration(days: 1));
          }
          final newTask = Map<String, dynamic>.from(data)
            ..remove('nextSpawned')
            ..remove('reminderDueSoon')
            ..remove('reminderOverdue')
            ..['deadline'] = Timestamp.fromDate(next)
            ..['createdAt'] = Timestamp.now()
            ..['isDone'] = false
            ..['status'] = TaskStatus.todo
            ..['comments'] = []
            ..['statusUpdatedAt'] = null
            ..['updatedAt'] = null;
          await _db.collection('tasks').add(newTask);
        }
      } catch (e) {
        debugPrint('Recurrence spawn failed: $e');
      }
    }

    // Notify the creator on completion / reopen.
    // (Push delivery happens in the Cloud Function, see createTask.)
    if (taskTitle != null && assignedBy != null && assignedBy != user?.uid) {
      if (status == TaskStatus.done) {
        saveNotification(
          recipientUid: assignedBy,
          title: 'Task Completed! ✅',
          body: '"$taskTitle" has been completed.',
          senderPhoto: user?.photoURL,
          data: {'type': 'TASK_COMPLETED', 'taskId': taskId},
        );
      } else {
        saveNotification(
          recipientUid: assignedBy,
          title: 'Task Reopened 🔄',
          body: '"$taskTitle" has been reopened.',
          senderPhoto: user?.photoURL,
          data: {'type': 'task_update', 'taskId': taskId},
        );
      }
    }
  }

  /// Legacy boolean API — delegates to setTaskStatus.
  Future<void> updateTaskStatus(String taskId, bool isDone, {String? taskTitle, String? assignedBy}) async {
    await setTaskStatus(taskId, isDone ? TaskStatus.done : TaskStatus.todo,
        taskTitle: taskTitle, assignedBy: assignedBy);
  }

  Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  Future<void> deleteCompletedTasks(String uid) async {
    final snapshots = await _db.collection('tasks')
        .where('assignedTo', isEqualTo: uid)
        .where('isDone', isEqualTo: true)
        .get();
    
    final batch = _db.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Live stream of a task's comments from the comments subcollection,
  /// oldest first. (Older comments stored in the task document's
  /// `comments` array are merged in by the UI for backward compatibility.)
  Stream<List<CommentModel>> getComments(String taskId) {
    return _db.collection('tasks').doc(taskId).collection('comments')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromMap(doc.data()))
            .toList());
  }

  Future<void> addComment(String taskId, CommentModel comment, String recipientUid, String taskTitle) async {
    // Comments live in their own subcollection — an array inside the task
    // document would hit Firestore's 1 MB document limit over time.
    await _db.collection('tasks').doc(taskId).collection('comments').add(comment.toMap());

    // Save the in-app notification for the recipient (push via Cloud Function)
    saveNotification(
      recipientUid: recipientUid,
      title: 'New Comment 💬',
      body: '${comment.userName}: ${comment.text}',
      senderPhoto: comment.userPhoto,
      data: {
        'type': 'COMMENT',
        'taskId': taskId,
      },
    );
  }

  Future<void> saveNotification({
    required String recipientUid,
    required String title,
    required String body,
    required Map<String, String> data,
    String? senderPhoto,
  }) async {
    await _db.collection('users').doc(recipientUid).collection('notifications').add({
      'title': title,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
      'isRead': false,
      'senderPhoto': senderPhoto,
    });
  }

  Stream<List<NotificationModel>> getNotifications(String uid) {
    return _db.collection('users').doc(uid).collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  Future<void> markAsRead(String uid, String notificationId) async {
    await _db.collection('users').doc(uid).collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> updateUserProfile(String uid, {String? name, String? photoUrl, String? designation}) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (designation != null) updates['designation'] = designation;
    
    if (updates.isNotEmpty) {
      await _db.collection('users').doc(uid).update(updates);
    }
  }

  Future<String> uploadProfileImage(String uid, File imageFile) async {
    return await SupabaseService.uploadFile('profiles', imageFile);
  }

  Future<String> uploadCommentImage(String taskId, File imageFile) async {
    return await SupabaseService.uploadFile('comments/$taskId', imageFile);
  }

  Future<String> uploadCommentAudio(String taskId, File audioFile) async {
    return await SupabaseService.uploadFile('comments/$taskId/audio', audioFile);
  }

  Future<String> uploadTaskImage(File imageFile) async {
    return await SupabaseService.uploadFile('tasks', imageFile);
  }

  Future<String> uploadTaskAudio(File audioFile) async {
    return await SupabaseService.uploadFile('tasks/audio', audioFile);
  }
}
