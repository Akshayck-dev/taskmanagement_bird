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
import 'package:taskflow_minimalist/widgets/app_widgets.dart';

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
            if (snapshot.hasError) {
              return const StreamErrorView(message: 'Could not load your tasks. Please check your connection and try again.');
            }
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
                  // Gradient hero header with progress ring
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: kBrandGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D5DF6).withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMM d').format(now),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.4),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_getGreeting()}, ${user.displayName?.split(' ')[0] ?? 'User'} 👋',
                                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                            ),
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
                                    smoothPageRoute(const NotificationScreen()),
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.notifications_none_rounded, size: 22, color: Colors.white),
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: 2,
                                          top: 2,
                                          child: Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: Colors.amberAccent,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.2),
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
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            ProgressRing(
                              progress: assignedTasks.isEmpty ? 0 : assignedTasks.where((t) => t.isDone).length / assignedTasks.length,
                              size: 74,
                              label: assignedTasks.isEmpty ? '0%' : '${(assignedTasks.where((t) => t.isDone).length / assignedTasks.length * 100).round()}%',
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assignedTasks.isEmpty
                                        ? 'No tasks assigned yet'
                                        : '${assignedTasks.where((t) => t.isDone).length} of ${assignedTasks.length} tasks done',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    activeAssignedCount == 0
                                        ? "You're all caught up. Nice work! 🎉"
                                        : activeAssignedCount == 1
                                            ? '1 task still needs your attention'
                                            : '$activeAssignedCount tasks still need your attention',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Three compact summary cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(context, 'Overdue', overdueCount, Icons.priority_high_rounded, Colors.redAccent, isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(context, 'Due Today', dueTodayCount, Icons.today_rounded, Colors.orange, isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(context, 'Upcoming', upcomingCount, Icons.upcoming_rounded, primaryColor, isDark),
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
                        return StaggeredFadeIn(
                          key: ValueKey(task.id),
                          index: index,
                          child: _buildCompactTaskCard(context, task, dbService, isDark, today),
                        );
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

  Widget _buildSummaryCard(BuildContext context, String label, int value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 10),
          AnimatedCount(
            value: value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54),
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
      dueBadge = IconChip(icon: Icons.check_circle_rounded, label: 'Completed', color: isDark ? Colors.white54 : Colors.black45);
    } else if (taskDate.isBefore(today)) {
      final daysDiff = today.difference(taskDate).inDays;
      dueBadge = IconChip(
        icon: Icons.error_rounded,
        label: daysDiff == 1 ? 'Overdue by 1 day' : 'Overdue by $daysDiff days',
        color: Colors.redAccent,
      );
    } else if (taskDate == today) {
      dueBadge = const IconChip(icon: Icons.today_rounded, label: 'Due Today', color: Colors.orange);
    } else if (taskDate == today.add(const Duration(days: 1))) {
      dueBadge = const IconChip(icon: Icons.event_rounded, label: 'Tomorrow', color: Color(0xFFD97706));
    } else {
      dueBadge = IconChip(icon: Icons.event_available_rounded, label: DateFormat('MMM d').format(task.deadline), color: Colors.green);
    }

    final priorityColor = priorityColorOf(task.priority);

    return GestureDetector(
      onTap: () => Navigator.push(context, smoothPageRoute(TaskDetailScreen(task: task))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Row(
          children: [
            // Priority bar
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: task.isDone ? (isDark ? Colors.white24 : Colors.black26) : priorityColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
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
                        : task.status == TaskStatus.inProgress
                            ? Colors.orange
                            : (isDark ? Colors.white30 : Colors.black38),
                    width: 1.5,
                  ),
                  shape: BoxShape.circle,
                ),
                child: task.isDone
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : task.status == TaskStatus.inProgress
                        ? const Icon(Icons.timelapse_rounded, size: 13, color: Colors.orange)
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
                      const SizedBox(width: 8),
                      Icon(categoryIcon(task.category), size: 12, color: categoryColor(task.category)),
                      const SizedBox(width: 3),
                      Text(
                        task.category,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: categoryColor(task.category)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // In Progress chip
            if (task.status == TaskStatus.inProgress) ...[
              const IconChip(icon: Icons.timelapse_rounded, label: 'In Progress', color: Colors.orange),
              const SizedBox(width: 6),
            ],
            // Priority Indicator / Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.1),
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
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [kBrandGradient[0].withValues(alpha: 0.16), kBrandGradient[2].withValues(alpha: 0.16)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(Icons.task_alt_rounded, size: 38, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No Assigned Tasks',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            "You're all caught up. New tasks will appear here.",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: isDark ? Colors.white38 : Colors.black45),
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

class _SkeletonItem extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const _SkeletonItem({
    this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerBlock(height: height, width: width, radius: borderRadius);
  }
}
