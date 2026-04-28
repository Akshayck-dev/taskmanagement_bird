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
  final DateTime timestamp;

  CommentModel({
    required this.uid,
    required this.userName,
    required this.userPhoto,
    required this.text,
    required this.timestamp,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      uid: map['uid'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userName': userName,
      'userPhoto': userPhoto,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String assignedTo;
  final String assignedBy;
  final bool isDone;
  final DateTime deadline;
  final DateTime createdAt;
  final String category;
  final String priority;
  final List<CommentModel> comments;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedBy,
    required this.isDone,
    required this.deadline,
    required this.createdAt,
    this.category = 'General',
    this.priority = 'Medium',
    this.comments = const [],
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      assignedBy: data['assignedBy'] ?? '',
      isDone: data['isDone'] ?? false,
      deadline: (data['deadline'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      category: data['category'] ?? 'General',
      priority: data['priority'] ?? 'Medium',
      comments: (data['comments'] as List? ?? [])
          .map((c) => CommentModel.fromMap(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'isDone': isDone,
      'deadline': Timestamp.fromDate(deadline),
      'createdAt': Timestamp.fromDate(createdAt),
      'category': category,
      'priority': priority,
      'comments': comments.map((c) => c.toMap()).toList(),
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
      timestamp: DateTime.parse(map['timestamp']),
      data: map['data'],
      isRead: map['isRead'] ?? false,
      senderPhoto: map['senderPhoto'],
    );
  }
}
