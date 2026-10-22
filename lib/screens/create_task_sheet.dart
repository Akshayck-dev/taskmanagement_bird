import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../widgets/app_widgets.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateTaskBottomSheet extends StatefulWidget {
  final String currentUserId;
  const CreateTaskBottomSheet({super.key, required this.currentUserId});

  @override
  State<CreateTaskBottomSheet> createState() => _CreateTaskBottomSheetState();
}

class _CreateTaskBottomSheetState extends State<CreateTaskBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedAssignee;
  String _selectedPriority = 'Medium';
  String _selectedCategory = 'General';
  String _selectedRecurrence = 'none';
  DateTime _selectedDeadline = DateTime.now().copyWith(hour: 18, minute: 0); // Default to today 6 PM
  bool _isLoading = false;
  bool _showMentions = false;
  List<AppUser> _allUsers = [];
  File? _taskImage;
  String? _audioPath;
  bool _isRecording = false;
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/task_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() => _taskImage = File(image.path));
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedAssignee = widget.currentUserId; // Default to self
    _descController.addListener(_onDescChanged);
  }

  void _onDescChanged() {
    final text = _descController.text;
    final cursorPosition = _descController.selection.baseOffset;
    if (cursorPosition > 0 && text.substring(0, cursorPosition).endsWith('@')) {
      setState(() => _showMentions = true);
    } else {
      if (_showMentions) setState(() => _showMentions = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.removeListener(_onDescChanged);
    _descController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20, 
        top: 16, 
        left: 20, 
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: StreamBuilder<List<AppUser>>(
        stream: dbService.getAllUsers(),
        builder: (context, snapshot) {
          _allUsers = snapshot.data ?? [];
          
          return Stack(
            clipBehavior: Clip.none,
            children: [
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12, 
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'New Task',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Title'),
                    TextField(
                      controller: _titleController,
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      decoration: _inputDecoration('What needs to be done?', isDark),
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('Description'),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      decoration: _inputDecoration('Add details. Type @ to assign someone...', isDark),
                    ),
                    const SizedBox(height: 14),

                    // Live Assignment Chip
                    if (_selectedAssignee != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (_selectedAssignee == widget.currentUserId ? Colors.orange : primaryColor).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedAssignee == widget.currentUserId ? Icons.lock_outline_rounded : Icons.person_outline_rounded,
                              size: 14,
                              color: _selectedAssignee == widget.currentUserId ? Colors.orange : primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedAssignee == widget.currentUserId
                                  ? 'Personal Task'
                                  : 'Assigned to: ${_allUsers.firstWhere((u) => u.uid == _selectedAssignee, orElse: () => AppUser(uid: '', name: 'Someone', email: '', photoUrl: '')).name}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedAssignee == widget.currentUserId ? Colors.orange : primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    _buildFieldLabel('Deadline'),
                    GestureDetector(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDeadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null && mounted) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedDeadline),
                          );
                          
                          setState(() {
                            _selectedDeadline = DateTime(
                              pickedDate.year, 
                              pickedDate.month, 
                              pickedDate.day, 
                              pickedTime?.hour ?? 18, 
                              pickedTime?.minute ?? 0,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 18, color: primaryColor),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEEE, MMM d, yyyy - h:mm a').format(_selectedDeadline),
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Priority'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TaskPriorities.all.map((pr) => taskOptionChip(
                        label: pr,
                        selected: _selectedPriority == pr,
                        onTap: () => setState(() => _selectedPriority = pr),
                        isDark: isDark,
                        primaryColor: primaryColor,
                      )).toList(),
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Category'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TaskCategories.all.map((cat) => taskOptionChip(
                        label: cat,
                        selected: _selectedCategory == cat,
                        onTap: () => setState(() => _selectedCategory = cat),
                        isDark: isDark,
                        primaryColor: primaryColor,
                      )).toList(),
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Repeat'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TaskRecurrence.all.map((r) => taskOptionChip(
                        label: TaskRecurrence.label(r),
                        selected: _selectedRecurrence == r,
                        onTap: () => setState(() => _selectedRecurrence = r),
                        isDark: isDark,
                        primaryColor: primaryColor,
                      )).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Attachments row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFieldLabel('Attachments'),
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(Icons.add, color: primaryColor, size: 18),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                          onSelected: (value) {
                            if (value == 'camera') _pickImage(ImageSource.camera);
                            if (value == 'gallery') _pickImage(ImageSource.gallery);
                            if (value == 'audio') _isRecording ? _stopRecording() : _startRecording();
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'camera', child: Row(children: [Icon(Icons.camera_alt_outlined, size: 16, color: primaryColor), const SizedBox(width: 8), const Text('Camera', style: TextStyle(fontSize: 13))])),
                            PopupMenuItem(value: 'gallery', child: Row(children: [Icon(Icons.image_outlined, size: 16, color: primaryColor), const SizedBox(width: 8), const Text('Gallery', style: TextStyle(fontSize: 13))])),
                            PopupMenuItem(value: 'audio', child: Row(children: [Icon(_isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded, size: 16, color: _isRecording ? Colors.red : primaryColor), const SizedBox(width: 8), Text(_isRecording ? 'Stop Recording' : 'Record Audio', style: TextStyle(fontSize: 13))])),
                          ],
                        ),
                      ],
                    ),
                    if (_taskImage != null || _audioPath != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_taskImage != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(_taskImage!, height: 60, width: 60, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _taskImage = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (_audioPath != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.audiotrack_rounded, size: 14, color: primaryColor),
                                  const SizedBox(width: 6),
                                  Text('Audio Recording', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(() => _audioPath = null),
                                    child: Icon(Icons.close, size: 12, color: primaryColor),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    PrimaryButton(
                      text: 'Create Task',
                      isLoading: _isLoading,
                      onPressed: () async {
                        final title = _titleController.text.trim();
                        final desc = _descController.text.trim();

                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a task title'), behavior: SnackBarBehavior.floating),
                          );
                          return;
                        }
                        if (desc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter task details/description'), behavior: SnackBarBehavior.floating),
                          );
                          return;
                        }
                        if (_selectedAssignee == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please assign this task to someone'), behavior: SnackBarBehavior.floating),
                          );
                          return;
                        }

                        if (_isRecording) {
                          await _stopRecording();
                        }

                        setState(() => _isLoading = true);
                        try {
                          String? imageUrl;
                          String? audioUrl;

                          final List<Future> uploads = [];
                          if (_taskImage != null && await _taskImage!.exists()) {
                            uploads.add(dbService.uploadTaskImage(_taskImage!).then((url) => imageUrl = url));
                          }
                          if (_audioPath != null && await File(_audioPath!).exists()) {
                            uploads.add(dbService.uploadTaskAudio(File(_audioPath!)).then((url) => audioUrl = url));
                          }

                          if (uploads.isNotEmpty) {
                            await Future.wait(uploads).timeout(const Duration(seconds: 45));
                          }

                          await dbService.createTask(TaskModel(
                            id: '',
                            title: title,
                            description: desc,
                            assignedTo: _selectedAssignee!,
                            assignedBy: widget.currentUserId,
                            isDone: false,
                            deadline: _selectedDeadline,
                            createdAt: DateTime.now(),
                            category: _selectedCategory,
                            recurrence: _selectedRecurrence,
                            priority: _selectedPriority,
                            imageUrl: imageUrl,
                            audioUrl: audioUrl,
                          ));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Task created successfully! ✅'), 
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error creating task: $e'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (_showMentions && _allUsers.isNotEmpty) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 120, // Above the create button and attachments row
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15), 
                          blurRadius: 15, 
                          offset: const Offset(0, 5),
                        )
                      ],
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        color: Colors.transparent,
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _allUsers.length,
                          itemBuilder: (context, index) {
                            final u = _allUsers[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 12, 
                                backgroundImage: u.photoUrl.isNotEmpty ? CachedNetworkImageProvider(u.photoUrl) : null,
                                backgroundColor: Colors.grey,
                                child: u.photoUrl.isEmpty ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
                              ),
                              title: Text(
                                u.uid == widget.currentUserId ? '${u.name} (Me)' : u.name, 
                                style: TextStyle(
                                  fontSize: 13, 
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              onTap: () {
                                final text = _descController.text;
                                final lastAtIndex = text.lastIndexOf('@');
                                setState(() {
                                  _descController.text = text.substring(0, lastAtIndex + 1) + u.name + ' ';
                                  _descController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _descController.text.length),
                                  );
                                  _selectedAssignee = u.uid; // Auto-assign!
                                  _showMentions = false;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ]
            ],
          );
        },
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.w600, 
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF2F2F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary, 
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

