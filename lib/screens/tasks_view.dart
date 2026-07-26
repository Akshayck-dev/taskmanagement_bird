import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taskflow_minimalist/models/app_models.dart';
import 'package:taskflow_minimalist/services/firebase_service.dart';
import 'package:taskflow_minimalist/services/theme_provider.dart';
import 'package:taskflow_minimalist/screens/notification_screen.dart';
import 'package:taskflow_minimalist/screens/task_detail_screen.dart';

class TasksView extends StatelessWidget {
  const TasksView({super.key});

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFFFFFFF),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<TaskModel>>(
          stream: dbService.getTasks(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoader(context, isDark);
            }

            final allTasks = snapshot.data ?? [];
            // Core Rule: A task is visible only to: Creator OR Assigned employee.
            // Home screen should display ONLY tasks assigned to the logged-in user.
            final assignedTasks = allTasks.where((t) => t.assignedTo == user.uid).toList();

            // Calculate counts for summary cards
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final tomorrow = today.add(const Duration(days: 1));

            int overdueCount = 0;
            int dueTodayCount = 0;
            int upcomingCount = 0;

            for (var task in assignedTasks) {
              if (task.isDone) continue;
              final taskDate = DateTime(task.deadline.year, task.deadline.month, task.deadline.day);
              if (taskDate.isBefore(today)) {
                overdueCount++;
              } else if (taskDate == today) {
                dueTodayCount++;
              } else {
                upcomingCount++;
              }
            }

            // Sort tasks:
            // 1. Overdue
            // 2. Due Today
            // 3. Tomorrow
            // 4. Upcoming
            // Completed tasks at the bottom
            final sortedTasks = List<TaskModel>.from(assignedTasks);
            sortedTasks.sort((a, b) {
              final scoreA = _getTaskPriorityScore(a, today);
              final scoreB = _getTaskPriorityScore(b, today);
              if (scoreA != scoreB) {
                return scoreA.compareTo(scoreB);
              }
              return a.deadline.compareTo(b.deadline);
            });

            final activeAssignedCount = assignedTasks.where((t) => !t.isDone).length;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile image & Greeting Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}, ${user.displayName?.split(' ')[0] ?? 'User'} 👋',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activeAssignedCount == 1
                                  ? "You have 1 assigned task"
                                  : "You have $activeAssignedCount assigned tasks",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Notifications Button
                      StreamBuilder<List<NotificationModel>>(
                        stream: dbService.getNotifications(user.uid),
                        builder: (context, notificationSnapshot) {
                          final unreadCount = notificationSnapshot.hasData
                              ? notificationSnapshot.data!.where((n) => !n.isRead).length
                              : 0;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const NotificationScreen()),
                            ),
                            behavior: HitTestBehavior.opaque,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF16161A) : const Color(0xFFF2F2F7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications_none_rounded,
                                    size: 22,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Three compact summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'Overdue',
                          '$overdueCount',
                          overdueCount > 0 ? Colors.redAccent : (isDark ? Colors.white24 : Colors.black38),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'Due Today',
                          '$dueTodayCount',
                          dueTodayCount > 0 ? Colors.orange : (isDark ? Colors.white24 : Colors.black38),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          'Upcoming',
                          '$upcomingCount',
                          upcomingCount > 0 ? primaryColor : (isDark ? Colors.white24 : Colors.black38),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Assigned Tasks Section
                  Text(
                    'Assigned Tasks',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (sortedTasks.isEmpty)
                    _buildEmptyState(context, isDark)
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedTasks.length + 1,
                      itemBuilder: (context, index) {
                        if (index == sortedTasks.length) {
                          return const SizedBox(height: 140);
                        }
                        final task = sortedTasks[index];
                        return _buildCompactTaskCard(context, task, dbService, isDark, today);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _getTaskPriorityScore(TaskModel task, DateTime today) {
    if (task.isDone) return 5;
    final taskDate = DateTime(task.deadline.year, task.deadline.month, task.deadline.day);
    if (taskDate.isBefore(today)) return 1; // Overdue
    if (taskDate == today) return 2; // Due Today
    if (taskDate == today.add(const Duration(days: 1))) return 3; // Tomorrow
    return 4; // Upcoming
  }

  Widget _buildSummaryCard(BuildContext context, String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTaskCard(
      BuildContext context, TaskModel task, DatabaseService db, bool isDark, DateTime today) {
    // Determine due status badge
    final taskDate = DateTime(task.deadline.year, task.deadline.month, task.deadline.day);
    Widget dueBadge;
    
    if (task.isDone) {
      dueBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Completed',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      );
    } else if (taskDate.isBefore(today)) {
      final daysDiff = today.difference(taskDate).inDays;
      final badgeText = daysDiff == 1 ? "Overdue by 1 day" : "Overdue by $daysDiff days";
      dueBadge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔴 ', style: TextStyle(fontSize: 10)),
          Text(
            badgeText,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.redAccent,
            ),
          ),
        ],
      );
    } else if (taskDate == today) {
      dueBadge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🟠 ', style: TextStyle(fontSize: 10)),
          Text(
            'Due Today',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.orange[800] ?? Colors.orange,
            ),
          ),
        ],
      );
    } else if (taskDate == today.add(const Duration(days: 1))) {
      dueBadge = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🟡 ', style: TextStyle(fontSize: 10)),
          Text(
            'Tomorrow',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.amber,
            ),
          ),
        ],
      );
    } else {
      dueBadge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🟢 ', style: TextStyle(fontSize: 10)),
          Text(
            DateFormat('MMM d').format(task.deadline),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
      );
    }

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
            // Status Checkbox (One-tap actionable)
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
                      // Creator info
                      Text(
                        'By ${task.assignedBy == task.assignedTo ? "Me" : "Someone"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Due badge
                      dueBadge,
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Priority Indicator / Status Chip
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

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '📋',
            style: TextStyle(
              fontSize: 36,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Assigned Tasks',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You're all caught up.",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonItem(width: 160, height: 22, borderRadius: 6),
                  const SizedBox(height: 8),
                  _SkeletonItem(width: 120, height: 14, borderRadius: 4),
                ],
              ),
              _SkeletonItem(width: 42, height: 42, borderRadius: 21),
            ],
          ),
          const SizedBox(height: 24),

          // Cards Skeleton
          Row(
            children: [
              Expanded(child: _SkeletonItem(height: 70, borderRadius: 16)),
              const SizedBox(width: 8),
              Expanded(child: _SkeletonItem(height: 70, borderRadius: 16)),
              const SizedBox(width: 8),
              Expanded(child: _SkeletonItem(height: 70, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 32),

          // Section Title Skeleton
          _SkeletonItem(width: 100, height: 16, borderRadius: 4),
          const SizedBox(height: 16),

          // Task List Skeleton
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SkeletonItem(height: 58, borderRadius: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonItem extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const _SkeletonItem({
    this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_SkeletonItem> createState() => _SkeletonItemState();
}

class _SkeletonItemState extends State<_SkeletonItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width ?? double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
