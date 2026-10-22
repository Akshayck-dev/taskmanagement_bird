import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String designation;
  final String? fcmToken;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    this.designation = 'Member',
    this.fcmToken,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      designation: map['designation'] ?? 'Member',
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'designation': designation,
      'fcmToken': fcmToken,
    };
  }
}

class CommentModel {
  final String uid;
  final String userName;
  final String userPhoto;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
  final DateTime timestamp;

  CommentModel({
    required this.uid,
    required this.userName,
    required this.userPhoto,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    required this.timestamp,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      uid: map['uid'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'],
      audioUrl: map['audioUrl'],
      timestamp: map['timestamp'] is Timestamp ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userName': userName,
      'userPhoto': userPhoto,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}



/// Recurrence options for a task ('none' = one-off).
class TaskRecurrence {
  static const List<String> all = ['none', 'daily', 'weekly', 'monthly'];

  static String label(String r) {
    switch (r) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return 'No repeat';
    }
  }
}

/// Categories offered in the create/edit task pickers.
class TaskCategories {
  static const List<String> all = ['General', 'Design', 'Development', 'Marketing', 'Operations', 'Personal'];
}

/// Priorities offered in the create/edit task pickers.
class TaskPriorities {
  static const List<String> all = ['Low', 'Medium', 'High'];
}

/// Workflow status values stored in TaskModel.status.
class TaskStatus {
  static const String todo = 'todo';
  static const String inProgress = 'in_progress';
  static const String done = 'done';
  static const List<String> all = [todo, inProgress, done];

  static String label(String status) {
    switch (status) {
      case inProgress:
        return 'In Progress';
      case done:
        return 'Done';
      default:
        return 'To Do';
    }
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String assignedTo;
  final String assignedBy;
  final bool isDone;
  final String status;
  final DateTime deadline;
  final DateTime createdAt;
  final String category;
  final String priority;
  final String? imageUrl;
  final String? audioUrl;
  final String recurrence;
  final List<CommentModel> comments;
  final DateTime? statusUpdatedAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedBy,
    required this.isDone,
    String? status,
    required this.deadline,
    required this.createdAt,
    this.category = 'General',
    this.priority = 'Medium',
    this.imageUrl,
    this.audioUrl,
    this.recurrence = 'none',
    this.comments = const [],
    this.statusUpdatedAt,
    this.updatedAt,
  }) : status = status ?? (isDone ? TaskStatus.done : TaskStatus.todo);

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      assignedBy: data['assignedBy'] ?? '',
      isDone: data['isDone'] ?? false,
      status: data['status'] ?? ((data['isDone'] ?? false) ? TaskStatus.done : TaskStatus.todo),
      deadline: data['deadline'] is Timestamp ? (data['deadline'] as Timestamp).toDate() : DateTime.now(),
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      category: data['category'] ?? 'General',
      priority: data['priority'] ?? 'Medium',
      imageUrl: data['imageUrl'],
      audioUrl: data['audioUrl'],
      recurrence: data['recurrence'] ?? 'none',
      comments: (data['comments'] as List? ?? [])
          .map((c) => CommentModel.fromMap(c as Map<String, dynamic>))
          .toList(),
      statusUpdatedAt: data['statusUpdatedAt'] != null ? (data['statusUpdatedAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'isDone': status == TaskStatus.done,
      'status': status,
      'deadline': Timestamp.fromDate(deadline),
      'createdAt': Timestamp.fromDate(createdAt),
      'category': category,
      'priority': priority,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'recurrence': recurrence,
      'comments': comments.map((c) => c.toMap()).toList(),
      'statusUpdatedAt': statusUpdatedAt != null ? Timestamp.fromDate(statusUpdatedAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final bool isRead;
  final String? senderPhoto;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.data,
    this.isRead = false,
    this.senderPhoto,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'isRead': isRead,
      'senderPhoto': senderPhoto,
    };
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      data: map['data'],
      isRead: map['isRead'] ?? false,
      senderPhoto: map['senderPhoto'],
    );
  }
}
