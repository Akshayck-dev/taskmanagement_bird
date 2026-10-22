import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../widgets/app_widgets.dart';
import 'dart:ui';
import "task_detail_screen.dart";

class MyTasksView extends StatefulWidget {
  const MyTasksView({super.key});

  @override
  State<MyTasksView> createState() => _MyTasksViewState();
}

class _MyTasksViewState extends State<MyTasksView> {
  int _selectedFilter = 0; // 0: All, 1: Active, 2: Completed
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _visibleCount = 25;
  final Set<String> _dismissedIds = {};

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
                  onChanged: (val) => setState(() {
                    _searchQuery = val.toLowerCase();
                    _visibleCount = 25;
                  }),
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
                  _filterTab('In Progress', 3, isDark),
                  _filterTab('Completed', 2, isDark),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: dbService.getTasks(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const StreamErrorView(message: 'Could not load your tasks. Please check your connection and try again.');
                  }
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
                    tasks = tasks.where((t) => t.title.toLowerCase().contains(_searchQuery) || t.description.toLowerCase().contains(_searchQuery)).toList();
                  }
                  if (_selectedFilter == 1) {
                    tasks = tasks.where((t) => !t.isDone).toList();
                  } else if (_selectedFilter == 2) {
                    tasks = tasks.where((t) => t.isDone).toList();
                  } else if (_selectedFilter == 3) {
                    tasks = tasks.where((t) => t.status == TaskStatus.inProgress).toList();
                  }

                  if (tasks.isEmpty) {
                    return _emptyState(context, isDark);
                  }

                  final visibleTasks = tasks.where((t) => !_dismissedIds.contains(t.id)).toList();
                  if (visibleTasks.isEmpty) {
                    return _emptyState(context, isDark);
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 240 && _visibleCount < visibleTasks.length) {
                          setState(() => _visibleCount += 25);
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 200),
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        itemCount: visibleTasks.length < _visibleCount ? visibleTasks.length : _visibleCount,
                        itemBuilder: (context, index) {
                          final task = visibleTasks[index];
                          return StaggeredFadeIn(
                            key: ValueKey(task.id),
                            index: index,
                            child: swipeableTaskCard(
                              context: context,
                              task: task,
                              dbService: dbService,
                              currentUid: user.uid,
                              onLocalDelete: () => setState(() => _dismissedIds.add(task.id)),
                              onDeleteFailed: () => setState(() => _dismissedIds.remove(task.id)),
                              child: _buildCompactTaskCard(context, task, dbService, isDark),
                            ),
                          );
                        },
                      ),
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
        onTap: () => setState(() {
            _selectedFilter = index;
            _visibleCount = 25;
          }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected && !isDark
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))]
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
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
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
              child: SizedBox(
                width: 38,
                height: 38,
                child: Center(
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
                      Icon(categoryIcon(task.category), size: 12, color: categoryColor(task.category)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          task.category,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: categoryColor(task.category),
                          ),
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

  Widget _emptyState(BuildContext context, bool isDark) {
    return Center(
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
            'Nothing here yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
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
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: ShimmerBlock(height: 58, radius: 14),
      ),
    );
  }
}

