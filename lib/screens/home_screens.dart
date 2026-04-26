import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../services/theme_provider.dart';
import '../services/fcm_v1_service.dart';
import '../widgets/app_widgets.dart';
import 'team_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: _screens[_selectedIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 65,
        width: 65,
        margin: const EdgeInsets.only(top: 30),
        child: FloatingActionButton(
          onPressed: () => _showCreateTaskSheet(context, user.uid),
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 35),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 80,
        padding: EdgeInsets.zero,
        notchMargin: 8,
        clipBehavior: Clip.antiAlias,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, Icons.home, 'Home', 0),
            _navItem(Icons.assignment_turned_in_outlined, Icons.assignment_turned_in, 'My Tasks', 1),
            const SizedBox(width: 40), // Space for FAB
            _navItem(Icons.people_outline, Icons.people, 'Team', 3),
            _navItem(Icons.person_outline, Icons.person, 'Profile', 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hi, ${user.displayName?.split(' ')[0] ?? 'User'} 👋',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Provider.of<ThemeProvider>(context).isDarkMode ? Icons.light_mode : Icons.dark_mode),
                      onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Provider.of<AuthService>(context, listen: false).signOut(),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(user.photoURL ?? ''),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<TaskModel>>(
              stream: dbService.getTasks(user.uid),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];
                final pendingCount = tasks.where((t) => !t.isDone).length;
                final completedCount = tasks.where((t) => t.isDone).length;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Pending',
                            count: pendingCount.toString(),
                            color: const Color(0xFF6C63FF).withOpacity(0.1),
                            icon: Icons.assignment,
                            iconColor: const Color(0xFF6C63FF),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            title: 'Completed',
                            count: completedCount.toString(),
                            color: Colors.green.withOpacity(0.1),
                            icon: Icons.check_circle,
                            iconColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('All Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final isOverdue = task.deadline.isBefore(DateTime.now());
                          return TaskItem(
                            title: task.title,
                            subtitle: '${DateFormat('dd MMM yyyy').format(task.deadline)}',
                            isDone: task.isDone,
                            isOverdue: isOverdue,
                            photoUrl: 'https://i.pravatar.cc/150?u=${task.assignedTo}',
                            onToggle: () => dbService.updateTaskStatus(task.id, !task.isDone, taskTitle: task.title, assignedBy: task.assignedBy),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
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
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: 'Task Title', filled: true, fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(hintText: 'Description', filled: true, fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<AppUser>>(
            stream: dbService.getAllUsers(),
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              return DropdownButtonFormField<String>(
                value: _selectedAssignee,
                decoration: InputDecoration(filled: true, fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.person_outline)),
                hint: const Text('Assign To'),
                items: users.map((u) => DropdownMenuItem(value: u.uid, child: Text(u.name))).toList(),
                onChanged: (val) => setState(() => _selectedAssignee = val),
              );
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            text: 'Create Task',
            onPressed: () async {
              if (_titleController.text.isNotEmpty && _selectedAssignee != null) {
                await dbService.createTask(TaskModel(
                  id: '',
                  title: _titleController.text,
                  description: _descController.text,
                  assignedTo: _selectedAssignee!,
                  assignedBy: widget.currentUserId,
                  isDone: false,
                  deadline: _selectedDate,
                  createdAt: DateTime.now(),
                ));
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Task Detail'), elevation: 0),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentTask.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(currentTask.description, style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5)),
                      const SizedBox(height: 32),
                      _DetailItem(label: 'Due Date', value: DateFormat('dd MMM yyyy').format(currentTask.deadline)),
                      const SizedBox(height: 16),
                      _DetailItem(label: 'Created At', value: DateFormat('dd MMM yyyy').format(currentTask.createdAt)),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mark as Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            Switch(
                              value: currentTask.isDone, 
                              onChanged: (val) {
                                dbService.updateTaskStatus(currentTask.id, val, taskTitle: currentTask.title, assignedBy: currentTask.assignedBy);
                                setState(() { currentTask = TaskModel(id: currentTask.id, title: currentTask.title, description: currentTask.description, assignedTo: currentTask.assignedTo, assignedBy: currentTask.assignedBy, isDone: val, deadline: currentTask.deadline, createdAt: currentTask.createdAt, comments: currentTask.comments); });
                              }, 
                              activeColor: const Color(0xFF6C63FF)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text('Comments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('tasks').doc(currentTask.id).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final taskData = TaskModel.fromFirestore(snapshot.data!);
                          final comments = taskData.comments;

                          if (comments.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.grey)),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final c = comments[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(radius: 18, backgroundImage: NetworkImage(c.userPhoto)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(c.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              Text(DateFormat('hh:mm a').format(c.timestamp), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(c.text, style: const TextStyle(fontSize: 14)),
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
              // Comment Input
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () async {
                          final text = _commentController.text.trim();
                          if (text.isNotEmpty && user != null) {
                            final comment = CommentModel(
                              uid: user.uid,
                              userName: user.displayName ?? 'Unknown',
                              userPhoto: user.photoURL ?? '',
                              text: text,
                              timestamp: DateTime.now(),
                            );
                            
                            // 1. Notify the primary recipient
                            final recipient = user.uid == currentTask.assignedTo ? currentTask.assignedBy : currentTask.assignedTo;
                            await dbService.addComment(currentTask.id, comment, recipient, currentTask.title);

                            // 2. Parse and notify @mentions
                            for (var teamUser in _allUsers) {
                              if (text.contains('@${teamUser.name}') && teamUser.uid != recipient && teamUser.uid != user.uid) {
                                await FcmV1Service.sendNotification(
                                  recipientUid: teamUser.uid,
                                  title: 'You were mentioned! 🔔',
                                  body: '${user.displayName} mentioned you in ${currentTask.title}',
                                );
                              }
                            }

                            _commentController.clear();
                            setState(() => _showMentions = false);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Mention List Dropdown
          if (_showMentions)
            StreamBuilder<List<AppUser>>(
              stream: dbService.getAllUsers(),
              builder: (context, snapshot) {
                _allUsers = snapshot.data ?? [];
                if (_allUsers.isEmpty) return const SizedBox();

                return Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _allUsers.length,
                      itemBuilder: (context, index) {
                        final u = _allUsers[index];
                        return ListTile(
                          leading: CircleAvatar(radius: 15, backgroundImage: NetworkImage(u.photoUrl)),
                          title: Text(u.name, style: const TextStyle(fontSize: 14)),
                          onTap: () {
                            final text = _commentController.text;
                            final lastAtIndex = text.lastIndexOf('@');
                            _commentController.text = text.substring(0, lastAtIndex + 1) + u.name + ' ';
                            _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
                            setState(() => _showMentions = false);
                          },
                        );
                      },
                    ),
                  ),
                );
              }
            ),
        ],
      ),
    );
  }
}

class MyTasksView extends StatelessWidget {
  const MyTasksView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user == null) return const SizedBox();
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks'), elevation: 0),
      body: StreamBuilder<List<TaskModel>>(
        stream: dbService.getTasks(user.uid),
        builder: (context, snapshot) {
          final tasks = snapshot.data?.where((t) => t.assignedTo == user.uid).toList() ?? [];
          if (tasks.isEmpty) return const Center(child: Text('No tasks assigned to you.'));

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return TaskItem(
                title: task.title,
                subtitle: DateFormat('dd MMM yyyy').format(task.deadline),
                isDone: task.isDone,
                isOverdue: task.deadline.isBefore(DateTime.now()),
                photoUrl: user.photoURL ?? '',
                onToggle: () => dbService.updateTaskStatus(task.id, !task.isDone, taskTitle: task.title, assignedBy: task.assignedBy),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task))),
              );
            },
          );
        },
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 50, backgroundImage: NetworkImage(user.photoURL ?? '')),
            const SizedBox(height: 16),
            Text(user.displayName ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user.email ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: PrimaryButton(
                text: 'Logout',
                color: Colors.red.withOpacity(0.1),
                textColor: Colors.red,
                onPressed: () => Provider.of<AuthService>(context, listen: false).signOut(),
              ),
            ),
          ],
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
