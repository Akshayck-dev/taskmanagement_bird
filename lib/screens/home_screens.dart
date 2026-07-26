import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../services/theme_provider.dart';
import '../services/fcm_v1_service.dart';
import '../widgets/app_widgets.dart';
import 'team_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'dart:io';
import 'notification_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import "tasks_view.dart";
import "task_detail_screen.dart";
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  final List<Widget> _screens = [
    const TasksView(), // Home
    const MyTasksView(), // My Tasks
    const SizedBox(), // Placeholder for FAB
    const TeamScreen(), // Team
    const ProfileScreen(), // Profile
  ];

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: _screens[_selectedIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 30),
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showCreateTaskSheet(context, user.uid),
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom > 0 ? 0 : 24, left: 32, right: 32),
        child: SafeArea(
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E).withOpacity(0.85) : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: BottomAppBar(
                  color: Colors.transparent,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navItem(Icons.grid_view_rounded, Icons.grid_view_rounded, 'Home', 0),
                      _navItem(Icons.task_alt_rounded, Icons.task_alt_rounded, 'Tasks', 1),
                      const SizedBox(width: 56), // Space for FAB
                      _navItem(Icons.group_rounded, Icons.group_rounded, 'Team', 3),
                      _navItem(Icons.person_rounded, Icons.person_rounded, 'Profile', 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[500],
                size: 24, // Slightly smaller icons for better balance
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[500],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateTaskSheet(BuildContext context, String currentUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskBottomSheet(currentUserId: currentUserId),
    );
  }
}

class _OldTasksView extends StatelessWidget {
  const _OldTasksView({super.key});

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user == null) return const SizedBox();
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()}, ${user.displayName?.split(' ')[0] ?? 'User'} 👋',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _actionIcon(
                        context, 
                        Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                        () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
                      ),
                      const SizedBox(width: 12),
                      StreamBuilder<List<NotificationModel>>(
                        stream: dbService.getNotifications(user.uid),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.hasData ? snapshot.data!.where((n) => !n.isRead).length : 0;
                          return _actionIcon(
                            context, 
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.notifications_none_rounded, size: 24),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                    ),
                                  ),
                              ],
                            ),
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen())),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 100),
                child: StreamBuilder<List<TaskModel>>(
                  stream: dbService.getTasks(user.uid),
                  builder: (context, snapshot) {
                    final allTasks = snapshot.data ?? [];
                    final tasks = allTasks.where((t) => t.assignedTo == user.uid || t.assignedBy == user.uid).toList();
                    
                    if (tasks.isEmpty) return _emptyState(context);

                    final pendingTasks = tasks.where((t) => !t.isDone).toList();
                    final completedTasks = tasks.where((t) => t.isDone).toList();

                    if (pendingTasks.isEmpty && tasks.isNotEmpty) {
                      return _allCompletedState(context);
                    }

                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    
                    final todayTasks = pendingTasks.where((t) => _isSameDay(t.deadline, today)).toList();
                    final upcomingTasks = pendingTasks.where((t) => t.deadline.isAfter(today.add(const Duration(days: 1)))).toList();

                    final otherTasks = pendingTasks.where((t) => !todayTasks.contains(t) && !upcomingTasks.contains(t)).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Section
                        Column(
                          children: [
                            _buildMiniStatCard(context, 'Active Tasks', pendingTasks.length.toString(), Icons.pending_actions_rounded, Theme.of(context).colorScheme.primary, isDark),
                            const SizedBox(height: 12),
                            _buildMiniStatCard(context, 'Assigned Tasks', tasks.where((t) => t.assignedBy == user.uid && t.assignedTo != user.uid).length.toString(), Icons.assignment_ind_rounded, const Color(0xFFE24C4C), isDark),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        Text(
                          'Your Tasks',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (todayTasks.isNotEmpty) ...[
                          _sectionHeader('Today'),
                          ...todayTasks.map((t) => _buildTaskItem(context, t, dbService)),
                        ],

                        if (upcomingTasks.isNotEmpty) ...[
                          _sectionHeader('Upcoming'),
                          ...upcomingTasks.map((t) => _buildTaskItem(context, t, dbService)),
                        ],
                        
                        // Remaining pending tasks that are neither today nor upcoming (overdue etc)
                        if (otherTasks.isNotEmpty) ...[
                          _sectionHeader('Other Pending'),
                          ...otherTasks.map((t) => _buildTaskItem(context, t, dbService)),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(BuildContext context, Widget icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
        ),
        child: icon,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskModel task, DatabaseService db) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 400),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: TaskItem(
        id: task.id,
        title: task.title,
        subtitle: DateFormat('MMM d, yyyy').format(task.deadline),
        isDone: task.isDone,
        isOverdue: task.deadline.isBefore(DateTime.now()) && !task.isDone,
        photoUrl: 'https://api.dicebear.com/7.x/initials/png?seed=${task.assignedTo}',
        category: task.category,
        priority: task.priority,
        canToggle: true,
        onToggle: () {
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          if (currentUid != task.assignedTo) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only the assigned person can change the status!'), behavior: SnackBarBehavior.floating));
            return;
          }
          final newStatus = !task.isDone;
          db.updateTaskStatus(task.id, newStatus, taskTitle: task.title, assignedBy: task.assignedBy);
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus ? 'Task completed! 🎉' : 'Task reopened 🔄'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task))),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.task_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No tasks found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create your first task!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allCompletedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF00B09B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFF00B09B)),
            ),
            const SizedBox(height: 24),
            Text(
              'All are completed!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Great job! You have cleared all your tasks.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard(BuildContext context, String title, String count, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF7A7A7A), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
      print('Error starting recording: $e');
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
      print('Error stopping recording: $e');
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
                          color: (_selectedAssignee == widget.currentUserId ? Colors.orange : primaryColor).withOpacity(0.1),
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
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
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

                    // Attachments row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFieldLabel('Attachments'),
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
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
                                color: primaryColor.withOpacity(0.1),
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
                            category: 'General',
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
              if (_showMentions && _allUsers.isNotEmpty && _allUsers.any((u) => u.name.startsWith('Tester'))) ...[
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
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.15), 
                          blurRadius: 15, 
                          offset: const Offset(0, 5),
                        )
                      ],
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        color: Colors.transparent,
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _allUsers.where((u) => u.name.startsWith('Tester')).length,
                          itemBuilder: (context, index) {
                            final testers = _allUsers.where((u) => u.name.startsWith('Tester')).toList();
                            final u = testers[index];
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
      fillColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF2F2F7),
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

class MyTasksView extends StatefulWidget {
  const MyTasksView({super.key});

  @override
  State<MyTasksView> createState() => _MyTasksViewState();
}

class _MyTasksViewState extends State<MyTasksView> {
  int _selectedFilter = 0; // 0: All, 1: Active, 2: Completed
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user == null) return const SizedBox();
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF0A0A0C) : const Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Tasks List',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.6,
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161A) : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Tabs / Segmented Control
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              padding: const EdgeInsets.all(3),
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16161A) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _filterTab('All', 0, isDark),
                  _filterTab('Active', 1, isDark),
                  _filterTab('Completed', 2, isDark),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: dbService.getTasks(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLoader(isDark);
                  }

                  final allTasks = snapshot.data ?? [];
                  // Show tasks assigned to current user OR tasks created by current user
                  var tasks = allTasks.where((t) => t.assignedTo == user.uid || t.assignedBy == user.uid).toList();

                  // Sort tasks: Active ones by nearest deadline, completed at the bottom
                  tasks.sort((a, b) {
                    if (a.isDone != b.isDone) {
                      return a.isDone ? 1 : -1;
                    }
                    return a.deadline.compareTo(b.deadline);
                  });

                  // Filter tasks
                  if (_searchQuery.isNotEmpty) {
                    tasks = tasks.where((t) => t.title.toLowerCase().contains(_searchQuery)).toList();
                  }
                  if (_selectedFilter == 1) {
                    tasks = tasks.where((t) => !t.isDone).toList();
                  } else if (_selectedFilter == 2) {
                    tasks = tasks.where((t) => t.isDone).toList();
                  }

                  if (tasks.isEmpty) {
                    return _emptyState(context, isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 200),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        return _buildCompactTaskCard(context, tasks[index], dbService, isDark);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterTab(String label, int index, bool isDark) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected && !isDark
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white38 : Colors.black45),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTaskCard(BuildContext context, TaskModel task, DatabaseService db, bool isDark) {
    final priorityColor = task.priority == 'High'
        ? Colors.redAccent
        : (task.priority == 'Medium' ? Colors.orangeAccent : Colors.blueAccent);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Row(
          children: [
            // Status Checkbox
            GestureDetector(
              onTap: () {
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                if (task.assignedTo != currentUid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Only the assigned person can change the status of this task'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                db.updateTaskStatus(task.id, !task.isDone, taskTitle: task.title, assignedBy: task.assignedBy);
                HapticFeedback.lightImpact();
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: task.isDone
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: task.isDone
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.white30 : Colors.black38),
                    width: 1.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: task.isDone
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 14),

            // Task Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: task.isDone
                          ? (isDark ? Colors.white38 : Colors.black38)
                          : (isDark ? Colors.white : Colors.black87),
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Due: ${DateFormat('MMM d').format(task.deadline)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
                      const SizedBox(width: 8),
                      Text(
                        task.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Priority Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                task.priority,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: priorityColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '📋',
            style: TextStyle(
              fontSize: 32,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Assigned Tasks',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You're all caught up.",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedOpacity(
          opacity: 0.6,
          duration: const Duration(milliseconds: 500),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  bool _isLoading = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF0A0A0C) : const Color(0xFFFFFFFF);
    final cardColor = isDark ? const Color(0xFF16161A) : const Color(0xFFF9F9FB);

    if (user == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        AppUser userData;
        if (snapshot.data!.exists && snapshot.data!.data() != null) {
          userData = AppUser.fromMap(snapshot.data!.data() as Map<String, dynamic>);
        } else {
          userData = AppUser(
            uid: user.uid,
            name: user.displayName ?? 'New User',
            email: user.email ?? '',
            designation: 'Member',
            photoUrl: user.photoURL ?? 'https://api.dicebear.com/7.x/initials/png?seed=${user.displayName ?? "U"}',
          );
        }

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // App Bar Title
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Profile Picture
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryColor, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            backgroundImage: _imageFile != null 
                                ? FileImage(_imageFile!) 
                                : (userData.photoUrl.isNotEmpty ? CachedNetworkImageProvider(userData.photoUrl) : null) as ImageProvider?,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name & Email
                  Text(
                    userData.name,
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.w700, 
                      color: isDark ? Colors.white : Colors.black87, 
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userData.email,
                    style: TextStyle(
                      fontSize: 13, 
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 3-Column Stats Row
                  StreamBuilder<List<TaskModel>>(
                    stream: DatabaseService().getTasks(user.uid),
                    builder: (context, taskSnapshot) {
                      int assigned = 0;
                      int completed = 0;
                      int created = 0;

                      if (taskSnapshot.hasData) {
                        final allTasks = taskSnapshot.data ?? [];
                        assigned = allTasks.where((t) => t.assignedTo == user.uid).length;
                        completed = allTasks.where((t) => t.assignedTo == user.uid && t.isDone).length;
                        created = allTasks.where((t) => t.assignedBy == user.uid).length;
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(cardColor, isDark, primaryColor, '$assigned', 'Assigned'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(cardColor, isDark, primaryColor, '$completed', 'Completed'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(cardColor, isDark, primaryColor, '$created', 'Created'),
                          ),
                        ],
                      );
                    }
                  ),
                  const SizedBox(height: 32),

                  // Settings / Toggle Section
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Appearance / Theme Toggle
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: primaryColor,
                          ),
                          title: Text(
                            'Appearance',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          trailing: Switch.adaptive(
                            value: isDark,
                            activeColor: primaryColor,
                            onChanged: (_) {
                              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Logout Button
                  GestureDetector(
                    onTap: () async {
                      await AuthService().signOut();
                      if (mounted) Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C1E1E) : const Color(0xFFFFF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.2),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'TaskFlow v3.0.0 (Stable)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white24 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(Color cardColor, bool isDark, Color primaryColor, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  const VoiceMessagePlayer({super.key, required this.url});

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerComplete.listen((_) => setState(() => _isPlaying = false));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
            color: Theme.of(context).colorScheme.primary,
            iconSize: 32,
            padding: EdgeInsets.zero,
            onPressed: () async {
              if (_isPlaying) {
                await _player.pause();
              } else {
                await _player.play(UrlSource(widget.url));
              }
              setState(() => _isPlaying = !_isPlaying);
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 12,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    thumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                    onChanged: (val) async {
                      await _player.seek(Duration(seconds: val.toInt()));
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}



class EditTaskBottomSheet extends StatefulWidget {
  final TaskModel task;
  const EditTaskBottomSheet({super.key, required this.task});

  @override
  State<EditTaskBottomSheet> createState() => _EditTaskBottomSheetState();
}

class _EditTaskBottomSheetState extends State<EditTaskBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedCategory;
  late String _selectedPriority;
  late DateTime _selectedDeadline;
  bool _isLoading = false;
  File? _taskImage;
  String? _audioPath;
  bool _isRecording = false;
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/task_audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      print("Error starting recording: $e");
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
      print("Error stopping recording: $e");
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
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _selectedCategory = widget.task.category;
    _selectedPriority = widget.task.priority;
    _selectedDeadline = widget.task.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF7A7A7A))),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildChip(String label, bool isSelected, Function() onTap, Color activeColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Colors.grey[400]!),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600], 
            fontWeight: FontWeight.bold, 
            fontSize: 12
          )
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24, 
        top: 20, 
        left: 24, 
        right: 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[isDark ? 800 : 300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Task', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildFieldLabel('Title'),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontWeight: FontWeight.w500),
              decoration: _inputDecoration('Task title...', isDark),
            ),
            const SizedBox(height: 20),
            
            _buildFieldLabel('Description'),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDecoration('Task description...', isDark),
            ),
            
            _buildFieldLabel('Deadline'),
            GestureDetector(
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDeadline,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate != null && mounted) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDeadline),
                  );
                  setState(() {
                    _selectedDeadline = DateTime(
                      pickedDate.year, pickedDate.month, pickedDate.day, 
                      pickedTime?.hour ?? 18, pickedTime?.minute ?? 0,
                    );
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 20, color: primaryColor),
                    const SizedBox(width: 12),
                    Text(DateFormat('MMM d, yyyy - h:mm a').format(_selectedDeadline), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFieldLabel("Attachment"),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary, size: 24),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  onSelected: (value) {
                    if (value == "camera") _pickImage(ImageSource.camera);
                    if (value == "gallery") _pickImage(ImageSource.gallery);
                    if (value == "audio") _isRecording ? _stopRecording() : _startRecording();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: "camera", child: Row(children: [const Icon(Icons.camera_alt_outlined, size: 20), const SizedBox(width: 12), const Text("Camera")])),
                    PopupMenuItem(value: "gallery", child: Row(children: [const Icon(Icons.image_outlined, size: 20), const SizedBox(width: 12), const Text("Gallery")])),
                    PopupMenuItem(value: "audio", child: Row(children: [Icon(_isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded, size: 20, color: _isRecording ? Colors.red : null), const SizedBox(width: 12), Text(_isRecording ? "Stop Recording" : "Record Audio")])),
                  ],
                ),
              ],
            ),
            if (_taskImage != null || _audioPath != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_taskImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_taskImage!, height: 80, width: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _taskImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_audioPath != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.audiotrack_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text("Audio Recording", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _audioPath = null),
                            child: Icon(Icons.close, size: 14, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            
            if (widget.task.updatedAt != null) ...[
              Center(
                child: Text(
                  'Last edited at: ${DateFormat('MMM d, h:mm a').format(widget.task.updatedAt!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            GestureDetector(
              onTap: _isLoading ? null : () async {
                if (_titleController.text.trim().isEmpty) return;
                if (_isRecording) await _stopRecording();
                setState(() => _isLoading = true);
                
                try {
                  final dbService = DatabaseService();
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
                    await Future.wait(uploads).timeout(const Duration(seconds: 60));
                  }
                  
                  await dbService.updateTaskDetails(
                    widget.task.id,
                    _titleController.text.trim(),
                    _descController.text.trim(),
                    _selectedCategory,
                    _selectedPriority,
                    _selectedDeadline,
                    imageUrl: imageUrl,
                    audioUrl: audioUrl,
                  );
                  
                  if (mounted) {
                    setState(() => _isLoading = false);
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Center(
                  child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
