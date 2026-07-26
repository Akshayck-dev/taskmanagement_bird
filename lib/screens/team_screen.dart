import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import 'task_detail_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? const Color(0xFF0A0A0C) : const Color(0xFFFFFFFF);
    final cardColor = isDark ? const Color(0xFF16161A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar / Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Collaborators',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
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
                    hintText: 'Search team members...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: dbService.getAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLoader(isDark);
                  }
                  final users = snapshot.data?.where((u) => u.name.toLowerCase().contains(_searchQuery)).toList() ?? [];

                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        'No members found',
                        style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: users.length + 1,
                    itemBuilder: (context, index) {
                      if (index == users.length) {
                        return const SizedBox(height: 140);
                      }
                      final user = users[index];

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MemberDetailScreen(user: user)),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: user.photoUrl.isNotEmpty ? CachedNetworkImageProvider(user.photoUrl) : null,
                                backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                child: user.photoUrl.isEmpty ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.designation.isNotEmpty ? user.designation : 'Team Member',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: isDark ? Colors.white38 : Colors.black45,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              StreamBuilder<List<TaskModel>>(
                                stream: dbService.getTasks(user.uid),
                                builder: (context, taskSnapshot) {
                                  final activeCount = taskSnapshot.hasData
                                      ? taskSnapshot.data!.where((t) => t.assignedTo == user.uid && !t.isDone).length
                                      : 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: activeCount > 0
                                          ? primaryColor.withOpacity(0.1)
                                          : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF2F2F7)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      activeCount == 1 ? '1 task' : '$activeCount tasks',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: activeCount > 0 ? primaryColor : (isDark ? Colors.white38 : Colors.black45),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ],
                          ),
                        ),
                      );
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

  Widget _buildSkeletonLoader(bool isDark) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedOpacity(
          opacity: 0.6,
          duration: const Duration(milliseconds: 500),
          child: Container(
            height: 64,
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

class MemberDetailScreen extends StatelessWidget {
  final AppUser user;
  const MemberDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 44,
              backgroundImage: user.photoUrl.isNotEmpty ? CachedNetworkImageProvider(user.photoUrl) : null,
              backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
              child: user.photoUrl.isEmpty ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.designation.isNotEmpty ? user.designation : 'Team Member',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user.email,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Assigned Tasks',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: dbService.getTasks(user.uid),
                builder: (context, snapshot) {
                  final tasks = snapshot.data?.where((t) => t.assignedTo == user.uid).toList() ?? [];
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📋', style: TextStyle(fontSize: 32, color: isDark ? Colors.white30 : Colors.black26)),
                          const SizedBox(height: 12),
                          Text(
                            'No tasks assigned yet',
                            style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: task.isDone
                                            ? (isDark ? Colors.white38 : Colors.black38)
                                            : (isDark ? Colors.white : Colors.black87),
                                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Due: ${DateFormat('MMM d, yyyy').format(task.deadline)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                task.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: task.isDone ? primaryColor : (isDark ? Colors.white30 : Colors.black38),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
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
}
