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
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:io';
import 'notification_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF3B33FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showCreateTaskSheet(context, user.uid),
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 36, color: Colors.white),
        ),
      ),
      bottomNavigationBar: Container(
        height: 90,
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.7),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              width: 0.5,
            ),
          ),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: BottomAppBar(
              height: 90,
              color: Colors.transparent,
              elevation: 0,
              padding: EdgeInsets.zero,
              notchMargin: 10,
              shape: const CircularNotchedRectangle(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(Icons.grid_view_rounded, Icons.grid_view_rounded, 'Home', 0),
                  _navItem(Icons.task_alt_rounded, Icons.task_alt_rounded, 'Tasks', 1),
                  const SizedBox(width: 70), // Increased space for FAB notch
                  _navItem(Icons.group_rounded, Icons.group_rounded, 'Team', 3),
                  _navItem(Icons.person_rounded, Icons.person_rounded, 'Profile', 4),
                ],
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
                color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[500],
                size: 24, // Slightly smaller icons for better balance
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[500],
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C63FF),
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

class TasksView extends StatelessWidget {
  const TasksView({super.key});

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
                        'Hi, ${user.displayName?.split(' ')[0] ?? 'User'} 👋',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: GoogleFonts.inter(
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
                                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
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
                    final tasks = allTasks.where((t) => t.assignedTo == user.uid).toList();
                    
                    if (tasks.isEmpty) return _emptyState();

                    final pendingTasks = tasks.where((t) => !t.isDone).toList();
                    final completedTasks = tasks.where((t) => t.isDone).toList();

                    if (pendingTasks.isEmpty && tasks.isNotEmpty) {
                      return _allCompletedState();
                    }

                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    
                    final todayTasks = pendingTasks.where((t) => _isSameDay(t.deadline, today)).toList();
                    final upcomingTasks = pendingTasks.where((t) => t.deadline.isAfter(today.add(const Duration(days: 1)))).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Section
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Active Tasks',
                                count: pendingTasks.length.toString(),
                                gradientColors: const [Color(0xFF6C63FF), Color(0xFF3B33FF)],
                                icon: Icons.pending_actions_rounded,
                              ),
                            ),
                            // We can add another useful stat here, like "Due Today"
                            const SizedBox(width: 16),
                            Expanded(
                              child: StatCard(
                                title: 'Due Today',
                                count: todayTasks.length.toString(),
                                gradientColors: const [Color(0xFFF2994A), Color(0xFFF2C94C)],
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        Text(
                          'Your Tasks',
                          style: GoogleFonts.inter(
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
                        final otherTasks = pendingTasks.where((t) => !todayTasks.contains(t) && !upcomingTasks.contains(t)).toList();
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
        style: GoogleFonts.inter(
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
        photoUrl: 'https://ui-avatars.com/api/?name=${task.assignedTo}&background=random',
        category: task.category,
        priority: task.priority,
        canToggle: true,
        onToggle: () {
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

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.task_rounded, size: 64, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 24),
            Text(
              'No tasks found',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create your first task!',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allCompletedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
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
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Great job! You have cleared all your tasks.',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
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
  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 1)).copyWith(hour: 18, minute: 0); // Default to tomorrow 6 PM
  DateTime _selectedDate = DateTime.now();
  bool _showMentions = false;
  bool _isLoading = false;
  List<AppUser> _allUsers = [];

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
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24, 
        top: 20, 
        left: 24, 
        right: 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[isDark ? 800 : 300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'New Task',
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                _buildFieldLabel('Title'),
                TextField(
                  controller: _titleController,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  decoration: _inputDecoration('Task title...'),
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Description'),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _inputDecoration('Type @ to mention and assign...'),
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (_selectedAssignee == widget.currentUserId ? Colors.orange : const Color(0xFF6C63FF)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedAssignee == widget.currentUserId ? Icons.sticky_note_2_outlined : Icons.person_outline_rounded, 
                          size: 14, 
                          color: _selectedAssignee == widget.currentUserId ? Colors.orange : const Color(0xFF6C63FF)
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedAssignee == widget.currentUserId 
                            ? 'Personal Note' 
                            : 'Assigned to: ${_allUsers.firstWhere((u) => u.uid == _selectedAssignee, orElse: () => AppUser(uid: '', name: 'Someone', email: '', photoUrl: '')).name}',
                          style: GoogleFonts.inter(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold, 
                            color: _selectedAssignee == widget.currentUserId ? Colors.orange : const Color(0xFF6C63FF)
                          ),
                        ),
                      ],
                    ),
                  ),
                // StreamBuilder is still needed to fetch users for mentions
                StreamBuilder<List<AppUser>>(
                  stream: dbService.getAllUsers(),
                  builder: (context, snapshot) {
                    _allUsers = snapshot.data ?? [];
                    return const SizedBox();
                  },
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Priority'),
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  decoration: _inputDecoration(''),
                  items: ['Low', 'Medium', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                   onChanged: (val) => setState(() => _selectedPriority = val!),
                ),
                const SizedBox(height: 20),
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
                      setState(() {
                        // Keep the time at 6:00 PM (End of business day)
                        _selectedDeadline = DateTime(
                          pickedDate.year, 
                          pickedDate.month, 
                          pickedDate.day, 
                          18, 0,
                        );
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE, MMM d, yyyy - 6:00 PM').format(_selectedDeadline),
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: 'Create Task',
                  isLoading: _isLoading,
                  onPressed: () async {
                    if (_titleController.text.isNotEmpty && _selectedAssignee != null) {
                      setState(() => _isLoading = true);
                      try {
                        await dbService.createTask(TaskModel(
                          id: '',
                          title: _titleController.text,
                          description: _descController.text,
                          assignedTo: _selectedAssignee!,
                          assignedBy: widget.currentUserId,
                          isDone: false,
                          deadline: _selectedDeadline,
                          createdAt: DateTime.now(),
                          category: 'General',
                          priority: _selectedPriority,
                        ));
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error creating task: $e')),
                          );
                        }
                      }
                    } else if (_selectedAssignee == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an assignee')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          if (_showMentions && _allUsers.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 250, // Above the assign field
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _allUsers.length,
                  itemBuilder: (context, index) {
                    final u = _allUsers[index];
                    return ListTile(
                      leading: CircleAvatar(radius: 14, backgroundImage: NetworkImage(u.photoUrl)),
                      title: Text(u.name, style: GoogleFonts.inter(fontSize: 14)),
                      onTap: () {
                        final text = _descController.text;
                        final lastAtIndex = text.lastIndexOf('@');
                        setState(() {
                          _descController.text = text.substring(0, lastAtIndex + 1) + u.name + ' ';
                          _descController.selection = TextSelection.fromPosition(TextPosition(offset: _descController.text.length));
                          _selectedAssignee = u.uid; // Auto-assign!
                          _showMentions = false;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700]),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    currentTask = widget.task;
    _commentController.addListener(_onCommentChanged);
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
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Text('Task Detail', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // Priority Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(currentTask.priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentTask.priority.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _getPriorityColor(currentTask.priority),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Hero(
                        tag: 'task_title_${currentTask.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            currentTask.title, 
                            style: GoogleFonts.inter(
                              fontSize: 32, 
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentTask.description, 
                        style: GoogleFonts.inter(
                          fontSize: 16, 
                          color: Colors.grey[500], 
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Details Grid
                      Row(
                        children: [
                          Expanded(child: _infoCard(context, Icons.calendar_today_rounded, 'Due Date', DateFormat('MMM d, yyyy').format(currentTask.deadline))),
                          const SizedBox(width: 16),
                          Expanded(child: _infoCard(context, Icons.category_outlined, 'Category', currentTask.category)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Status Toggle
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                        ),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('tasks').doc(currentTask.id).snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                            }
                            
                            final liveTask = TaskModel.fromFirestore(snapshot.data!);
                            final currentUid = FirebaseAuth.instance.currentUser?.uid;
                            // SWAPPED LOGIC: Only the person it is assigned TO can change the status
                            final bool canChangeStatus = currentUid != null && currentUid == liveTask.assignedTo;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Task Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(liveTask.isDone ? 'Completed' : 'In Progress', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                if (canChangeStatus)
                                  Switch(
                                    value: liveTask.isDone, 
                                    onChanged: (val) {
                                      dbService.updateTaskStatus(liveTask.id, val, taskTitle: liveTask.title, assignedBy: liveTask.assignedBy);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(val ? 'Task completed! 🎉' : 'Task reopened 🔄'),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }, 
                                    activeColor: const Color(0xFF6C63FF),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'View Only',
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            );
                          }
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      Text('Comments', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('tasks').doc(currentTask.id).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final taskData = TaskModel.fromFirestore(snapshot.data!);
                          final comments = taskData.comments;

                          if (comments.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.forum_outlined, size: 48, color: Colors.grey[300]),
                                    const SizedBox(height: 12),
                                    Text('No comments yet', style: GoogleFonts.inter(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final c = comments[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(radius: 20, backgroundImage: NetworkImage(c.userPhoto)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(c.userName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                              Text(DateFormat('hh:mm a').format(c.timestamp), style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(c.text, style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.black87, height: 1.4)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
              
              // Comment Input Field
              Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : (MediaQuery.of(context).padding.bottom + 16)),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))),
                ),
                child: Row(
                  children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: GoogleFonts.inter(),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: GoogleFonts.inter(color: Colors.grey),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isSending ? null : () async {
                          final text = _commentController.text.trim();
                          if (text.isNotEmpty && user != null) {
                            setState(() => _isSending = true);
                            try {
                              final comment = CommentModel(
                                uid: user.uid,
                                userName: user.displayName ?? 'Unknown',
                                userPhoto: user.photoURL ?? '',
                                text: text,
                                timestamp: DateTime.now(),
                              );
                              final recipient = user.uid == currentTask.assignedTo ? currentTask.assignedBy : currentTask.assignedTo;
                              await dbService.addComment(currentTask.id, comment, recipient, currentTask.title);
                              _commentController.clear();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Comment posted! 💬'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isSending = false);
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isSending 
                                ? [Colors.grey, Colors.grey.shade600]
                                : [const Color(0xFF6C63FF), const Color(0xFF3B33FF)]
                            ),
                          ),
                          child: _isSending 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return Colors.redAccent;
      case 'medium': return Colors.orangeAccent;
      case 'low': return Colors.blueAccent;
      default: return Colors.grey;
    }
  }
}

class MyTasksView extends StatefulWidget {
  const MyTasksView({super.key});

  @override
  State<MyTasksView> createState() => _MyTasksViewState();
}

class _MyTasksViewState extends State<MyTasksView> {
  int _selectedRole = 0; // 0 for "My Work", 1 for "Delegated"

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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Tasks',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      _actionIcon(
                        context, 
                        const Icon(Icons.cleaning_services_rounded, size: 22, color: Colors.orange),
                        () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clean Up?'),
                              content: const Text('This will permanently delete all your completed tasks. This action cannot be undone.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true), 
                                  child: const Text('Delete All', style: TextStyle(color: Colors.red))
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await dbService.deleteCompletedTasks(user.uid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Completed tasks cleared! ✨')),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      _actionIcon(
                        context, 
                        const Icon(Icons.notifications_none_rounded, size: 24),
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen())),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Premium Role Switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.all(4),
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _roleTab('My Work', 0, isDark),
                  _roleTab('Delegated', 1, isDark),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: dbService.getTasks(user.uid),
                builder: (context, snapshot) {
                  final allTasks = snapshot.data ?? [];
                  final tasks = _selectedRole == 0
                      ? allTasks.where((t) => t.assignedTo == user.uid).toList()
                      : allTasks.where((t) => t.assignedBy == user.uid && t.assignedTo != user.uid).toList();

                  if (tasks.isEmpty) return _emptyState();

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskItem(context, tasks[index], dbService);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleTab(String label, int index, bool isDark) {
    final isSelected = _selectedRole == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? const Color(0xFF6C63FF) : Colors.white) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !isDark 
                ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected 
                    ? (isDark ? Colors.white : const Color(0xFF6C63FF)) 
                    : Colors.grey[500],
              ),
            ),
          ),
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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedRole == 0 ? Icons.assignment_turned_in_outlined : Icons.hail_rounded, 
            size: 64, 
            color: Colors.grey[300]
          ),
          const SizedBox(height: 16),
          Text(
            _selectedRole == 0 ? 'No tasks assigned to you' : 'No delegated tasks found', 
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
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
        photoUrl: 'https://ui-avatars.com/api/?name=${task.assignedTo.substring(0, 2)}&background=random',
        category: task.category,
        priority: task.priority,
        canToggle: _selectedRole == 0,
        onToggle: () {
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

  Future<void> _saveProfile(String uid) async {
    setState(() => _isLoading = true);
    try {
      String? photoUrl;
      if (_imageFile != null) {
        photoUrl = await DatabaseService().uploadProfileImage(uid, _imageFile!);
      }

      await DatabaseService().updateUserProfile(
        uid,
        name: _nameController.text.trim(),
        designation: _designationController.text.trim(),
        photoUrl: photoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final userData = AppUser.fromMap(snapshot.data!.data() as Map<String, dynamic>);
        
        // Only set controllers if they are empty (first load)
        if (_nameController.text.isEmpty) _nameController.text = userData.name;
        if (_designationController.text.isEmpty) _designationController.text = userData.designation;

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Compact Header
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6C63FF), const Color(0xFF3B33FF).withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: _imageFile != null 
                                ? FileImage(_imageFile!) 
                                : (userData.photoUrl.isNotEmpty ? NetworkImage(userData.photoUrl) : null) as ImageProvider?,
                            child: (userData.photoUrl.isEmpty && _imageFile == null) 
                                ? const Icon(Icons.person, size: 40) 
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Color(0xFF6C63FF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userData.name,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    userData.designation,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Account Information', isDark),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _designationController,
                    label: 'Designation',
                    icon: Icons.work_outline_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: TextEditingController(text: userData.email),
                    label: 'Email',
                    icon: Icons.email_outlined,
                    isDark: isDark,
                    enabled: false,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    PrimaryButton(
                      text: 'Save Changes',
                      onPressed: () => _saveProfile(user.uid),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (mounted) Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text('Logout', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 100), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF6C63FF).withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
