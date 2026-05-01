import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/app_models.dart';
import 'fcm_v1_service.dart';
import 'supabase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');
      // Add a timeout to avoid hanging forever
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('Google Sign-In timed out');
          throw Exception('Sign-in timed out. Please try again.');
        },
      );

      if (googleUser == null) {
        print('Google Sign-In canceled by user');
        return null;
      }

      print('Google Sign-In successful, getting authentication...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Authenticating with Firebase...');
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
        print('User saved to Firestore: ${user.uid}');
      }

      return user;
    } catch (e) {
      print('--- GOOGLE SIGN-IN ERROR ---');
      print('Type: ${e.runtimeType}');
      print('Details: $e');
      if (e.toString().contains('10')) {
        print('SUGGESTION: Error 10 usually means the SHA-1 is missing in Firebase or the Support Email is not set.');
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
      print('Email Sign-In Error: $e');
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
          'photoUrl': 'https://ui-avatars.com/api/?name=$name&background=random',
          'lastSeen': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
      return user;
    } catch (e) {
      print('Email Registration Error: $e');
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
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: "taskmanagment-d25b4.appspot.com");

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

  // Stream of all users for assignment
  Stream<List<AppUser>> getAllUsers() {
    return _db.collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromMap(doc.data()))
            .toList());
  }

  Future<void> addDummyUsers() async {
    final dummyUsers = [
      {
        'uid': 'dummy_user_1',
        'name': 'Sarah Developer',
        'email': 'sarah.dev@example.com',
        'photoUrl': 'https://i.pravatar.cc/150?img=5',
        'lastSeen': DateTime.now().toIso8601String(),
      },
      {
        'uid': 'dummy_user_2',
        'name': 'Mike Designer',
        'email': 'mike.design@example.com',
        'photoUrl': 'https://i.pravatar.cc/150?img=11',
        'lastSeen': DateTime.now().toIso8601String(),
      },
      {
        'uid': 'dummy_user_3',
        'name': 'Alex Manager',
        'email': 'alex.man@example.com',
        'photoUrl': 'https://i.pravatar.cc/150?img=33',
        'lastSeen': DateTime.now().toIso8601String(),
      }
    ];

    for (var user in dummyUsers) {
      await _db.collection('users').doc(user['uid'] as String).set(user, SetOptions(merge: true));
    }
    print('Dummy users added for testing!');
  }

  Future<void> createTask(TaskModel task) async {
    final docRef = await _db.collection('tasks').add(task.toMap());
    
    // Send Notification to assigned user (Background)
    final data = {'type': 'NEW_TASK', 'taskId': docRef.id};
    FcmV1Service.sendNotification(
      recipientUid: task.assignedTo,
      title: 'New Task Assigned 📝',
      body: 'You have been assigned: ${task.title}',
      data: data,
    );

    // Save Notification for assigned user (Background)
    saveNotification(
      recipientUid: task.assignedTo,
      title: 'New Task Assigned 📋',
      body: '${user?.displayName ?? "Someone"} assigned: ${task.title}',
      senderPhoto: user?.photoURL,
      data: {
        'type': 'task_assigned',
        'taskId': docRef.id,
      },
    );
  }

  Future<void> updateTaskStatus(String taskId, bool isDone, {String? taskTitle, String? assignedBy}) async {
    await _db.collection('tasks').doc(taskId).update({'isDone': isDone});
    final user = _auth.currentUser;

    // If task is marked as done, notify the creator (Background)
    if (isDone && taskTitle != null && assignedBy != null) {
      final data = {'type': 'TASK_COMPLETED', 'taskId': taskId};
      FcmV1Service.sendNotification(
        recipientUid: assignedBy,
        title: 'Task Completed! ✅',
        body: '"$taskTitle" has been completed.',
        data: data,
      );

      // Save Notification for the person who assigned the task (Background)
      saveNotification(
        recipientUid: assignedBy,
        title: isDone ? 'Task Completed! ✅' : 'Task Reopened 🔄',
        body: '"$taskTitle" has been ${isDone ? 'completed' : 'reopened'}.',
        senderPhoto: user?.photoURL,
        data: {
          'type': 'task_update',
          'taskId': taskId,
        },
      );
    }
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

  Future<void> addComment(String taskId, CommentModel comment, String recipientUid, String taskTitle) async {
    await _db.collection('tasks').doc(taskId).update({
      'comments': FieldValue.arrayUnion([comment.toMap()])
    });

    // Notify the other party
    final data = {'taskId': taskId, 'type': 'COMMENT'};
    await FcmV1Service.sendNotification(
      recipientUid: recipientUid,
      title: 'New Comment 💬',
      body: '${comment.userName}: ${comment.text}',
      data: data,
    );

    // Save Notification for the recipient
    await saveNotification(
      recipientUid: recipientUid,
      title: 'New Comment 💬',
      body: '${comment.userName}: ${comment.text}',
      senderPhoto: comment.userPhoto,
      data: {
        'type': 'new_comment',
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
