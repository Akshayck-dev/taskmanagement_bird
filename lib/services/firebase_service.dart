import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';
import 'fcm_v1_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Save user to Firestore
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? 'Unknown',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
        }, SetOptions(merge: true));
      }

      return user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of tasks assigned to or by the user
  Stream<List<TaskModel>> getTasks(String uid) {
    return _db.collection('tasks')
        .where('assignedTo', isEqualTo: uid)
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
    await _db.collection('tasks').add(task.toMap());
    
    // Send Notification to assigned user
    await FcmV1Service.sendNotification(
      recipientUid: task.assignedTo,
      title: 'New Task Assigned 📝',
      body: 'You have been assigned: ${task.title}',
      data: {'type': 'NEW_TASK'},
    );
  }

  Future<void> updateTaskStatus(String taskId, bool isDone, {String? taskTitle, String? assignedBy}) async {
    await _db.collection('tasks').doc(taskId).update({'isDone': isDone});

    // If task is marked as done, notify the creator
    if (isDone && taskTitle != null && assignedBy != null) {
      await FcmV1Service.sendNotification(
        recipientUid: assignedBy,
        title: 'Task Completed! ✅',
        body: '"$taskTitle" has been completed.',
        data: {'type': 'TASK_COMPLETED'},
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  Future<void> addComment(String taskId, CommentModel comment, String recipientUid, String taskTitle) async {
    await _db.collection('tasks').doc(taskId).update({
      'comments': FieldValue.arrayUnion([comment.toMap()])
    });

    // Notify the other party
    await FcmV1Service.sendNotification(
      recipientUid: recipientUid,
      title: 'New Comment 💬',
      body: '${comment.userName}: ${comment.text}',
      data: {'taskId': taskId, 'type': 'COMMENT'},
    );
  }
}
