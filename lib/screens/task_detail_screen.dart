import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../widgets/app_widgets.dart';
import 'home_screens.dart' show VoiceMessagePlayer, EditTaskBottomSheet;
import 'package:cached_network_image/cached_network_image.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  late TaskModel currentTask;
  bool _showMentions = false;
  bool _isSending = false;
  List<AppUser> _allUsers = [];
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  
  // Audio Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    currentTask = widget.task;
    _commentController.addListener(_onCommentChanged);
  }


  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = "${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedImage == null && _audioPath == null) return;
    
    setState(() => _isSending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not authenticated");
      
      final dbService = DatabaseService();
      String? imageUrl;
      String? audioUrl;
      
      if (_selectedImage != null) {
        imageUrl = await dbService.uploadCommentImage(currentTask.id, _selectedImage!);
      }
      if (_audioPath != null) {
        audioUrl = await dbService.uploadCommentAudio(currentTask.id, File(_audioPath!));
      }
      
      final comment = CommentModel(
        uid: user.uid,
        userName: user.displayName ?? 'Anonymous',
        userPhoto: user.photoURL ?? 'https://api.dicebear.com/7.x/initials/png?seed=${user.displayName ?? "Anonymous"}',
        text: text,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        timestamp: DateTime.now(),
      );
      
      final recipient = user.uid == currentTask.assignedTo ? currentTask.assignedBy : currentTask.assignedTo;
      await dbService.addComment(currentTask.id, comment, recipient, currentTask.title);
      
      _commentController.clear();
      setState(() {
        _selectedImage = null;
        _audioPath = null;
        _isSending = false;
      });
    } catch (e) {
      debugPrint("Error submitting comment: $e");
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    final text = _commentController.text;
    final cursorPosition = _commentController.selection.baseOffset;
    
    if (cursorPosition > 0 && text.substring(0, cursorPosition).endsWith('@')) {
      setState(() => _showMentions = true);
    } else if (_showMentions && !text.contains('@')) {
      setState(() => _showMentions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF9F9FB);
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Task Details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('tasks').doc(widget.task.id).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final liveTask = TaskModel.fromFirestore(snapshot.data!);
                if (liveTask.isDone) return const SizedBox(); // Hide edit option if completed
                return IconButton(
                  icon: Icon(Icons.more_horiz_rounded, color: primaryColor),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => EditTaskBottomSheet(task: liveTask),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('tasks').doc(widget.task.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final liveTask = TaskModel.fromFirestore(snapshot.data!);
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final bool canChangeStatus = currentUid != null && currentUid == liveTask.assignedTo;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Interactive Status Pill & optional Non-General Category
                      Row(
                        children: [
                          GestureDetector(
                            onTap: canChangeStatus
                                ? () {
                                    dbService.updateTaskStatus(
                                      liveTask.id,
                                      !liveTask.isDone,
                                      taskTitle: liveTask.title,
                                      assignedBy: liveTask.assignedBy,
                                    );
                                    HapticFeedback.lightImpact();
                                  }
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: liveTask.isDone
                                    ? Colors.green.withOpacity(0.12)
                                    : primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    liveTask.isDone
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 14,
                                    color: liveTask.isDone ? Colors.green : primaryColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    liveTask.isDone ? 'Completed' : 'Mark Complete',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: liveTask.isDone ? Colors.green : primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (liveTask.category != 'General') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                liveTask.category,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Task Title
                      Text(
                        liveTask.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.6,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Clean Due Date Line
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Due ${DateFormat('MMM d, h:mm a').format(liveTask.deadline)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),

                      // Clean Borderless Description
                      if (liveTask.description.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          liveTask.description.replaceAll(RegExp(r'@Tester\s?\d\s?'), '').trim(),
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white70 : const Color(0xFF333333),
                            height: 1.55,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],

                      // Minimal Hairline Divider
                      const SizedBox(height: 24),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                      ),

                      // Attachments Section
                      if (liveTask.imageUrl != null || liveTask.audioUrl != null) ...[
                        const SizedBox(height: 28),
                        Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (liveTask.imageUrl != null)
                          _buildImageAttachmentCard(isDark, cardColor, 'Attached Image', 'Image File', liveTask.imageUrl!),
                        if (liveTask.audioUrl != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF16161A) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                            ),
                            child: VoiceMessagePlayer(url: liveTask.audioUrl!),
                          ),
                        ],
                      ],

                      // Activity / Timeline Section
                      const SizedBox(height: 28),
                      Text(
                        'Activity & Comments',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),

                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('tasks').doc(liveTask.id).snapshots(),
                        builder: (context, commentSnapshot) {
                          if (!commentSnapshot.hasData) return const SizedBox();
                          final taskData = TaskModel.fromFirestore(commentSnapshot.data!);
                          final comments = taskData.comments;

                          if (comments.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'No comments yet',
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                                ),
                              ),
                            );
                          }

                          final currentUid = FirebaseAuth.instance.currentUser?.uid;
                          return ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(top: 8),
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final c = comments[index];
                              final isMe = currentUid != null && c.uid == currentUid;
                              return _buildChatItem(
                                isDark: isDark,
                                cardColor: cardColor,
                                primaryColor: primaryColor,
                                isMe: isMe,
                                name: c.userName,
                                time: DateFormat('h:mm a').format(c.timestamp),
                                content: c.text,
                                photoUrl: c.userPhoto,
                                imageUrl: c.imageUrl,
                                audioUrl: c.audioUrl,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Comment Input bar
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom + 8
                      : 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161A) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(_selectedImage!, height: 60, width: 60, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 10, color: Colors.white),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    if (_audioPath != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.audiotrack_rounded, color: primaryColor, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Voice note recorded',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _audioPath = null),
                                child: Icon(Icons.close, size: 16, color: primaryColor),
                              )
                            ],
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          PopupMenuButton<String>(
                            icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            offset: const Offset(0, -90),
                            onSelected: (value) {
                              if (value == 'image') _pickImage(ImageSource.gallery);
                              if (value == 'audio') _isRecording ? _stopRecording() : _startRecording();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'image',
                                child: Row(children: [Icon(Icons.image_outlined, size: 16, color: primaryColor), const SizedBox(width: 8), const Text('Photo', style: TextStyle(fontSize: 13))]),
                              ),
                              PopupMenuItem(
                                value: 'audio',
                                child: Row(children: [Icon(_isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded, size: 16, color: _isRecording ? Colors.red : primaryColor), const SizedBox(width: 8), Text(_isRecording ? 'Stop Recording' : 'Voice Note', style: TextStyle(fontSize: 13))]),
                              ),
                            ],
                          ),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              maxLines: 3,
                              minLines: 1,
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _isSending ? null : _submitComment,
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                              child: _isSending
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }



  Widget _buildTag(String text, Color bgColor, Color textColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: isDark ? bgColor.withOpacity(0.1) : bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: isDark ? Colors.white70 : textColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }

  Widget _buildFileAttachmentCard(bool isDark, Color cardColor, String name, String subtitle, Color iconBg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0)),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.picture_as_pdf_rounded, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF333333))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF7A7A7A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAttachmentCard(bool isDark, Color cardColor, String name, String size, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0)),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            child: CachedNetworkImage(imageUrl: imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF333333))),
                    const SizedBox(height: 4),
                    Text(size, style: const TextStyle(fontSize: 12, color: Color(0xFF7A7A7A))),
                  ],
                ),
                Icon(Icons.file_download_outlined, color: const Color(0xFF7A7A7A)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatItem({
    required bool isDark,
    required Color cardColor,
    required Color primaryColor,
    required bool isMe,
    required String name,
    required String time,
    required String content,
    String? photoUrl,
    String? imageUrl,
    String? audioUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundImage: CachedNetworkImageProvider(
                photoUrl != null && photoUrl.isNotEmpty
                    ? photoUrl
                    : 'https://api.dicebear.com/7.x/initials/png?seed=$name',
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? primaryColor
                        : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            height: 140,
                            width: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (audioUrl != null && audioUrl.isNotEmpty) ...[
                        VoiceMessagePlayer(url: audioUrl),
                        const SizedBox(height: 6),
                      ],
                      if (content.isNotEmpty)
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            height: 1.4,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: isMe
                              ? Colors.white.withOpacity(0.75)
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
