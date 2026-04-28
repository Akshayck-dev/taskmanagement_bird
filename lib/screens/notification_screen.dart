import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';
import 'home_screens.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _filterChip('All'),
                  _filterChip('Unread'),
                  _filterChip('Mentions'),
                  _filterChip('Updates'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notification List
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: dbService.getNotifications(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var notifications = snapshot.data ?? [];
                  
                  // Apply Filter
                  if (_activeFilter == 'Unread') {
                    notifications = notifications.where((n) => !n.isRead).toList();
                  }

                  if (notifications.isEmpty) {
                    return _emptyState();
                  }

                  // Split into New and Earlier
                  final now = DateTime.now();
                  final newNotifs = notifications.where((n) => 
                    n.timestamp.day == now.day && 
                    n.timestamp.month == now.month && 
                    n.timestamp.year == now.year
                  ).toList();
                  final earlierNotifs = notifications.where((n) => !newNotifs.contains(n)).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (newNotifs.isNotEmpty) ...[
                        const Text('New', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...newNotifs.map((n) => _notificationItem(n, isDark, dbService, user.uid)),
                        const SizedBox(height: 24),
                      ],
                      if (earlierNotifs.isNotEmpty) ...[
                        const Text('Earlier', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...earlierNotifs.map((n) => _notificationItem(n, isDark, dbService, user.uid)),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _activeFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _activeFilter = label);
        },
        selectedColor: const Color(0xFF6C63FF),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _notificationItem(NotificationModel n, bool isDark, DatabaseService db, String uid) {
    final iconColor = _getIconColor(n.title);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GestureDetector(
        onTap: () async {
          await db.markAsRead(uid, n.id);
          if (n.data != null && n.data!['taskId'] != null) {
            _navigateToTask(context, n.data!['taskId']);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon or Profile Picture
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: n.senderPhoto != null ? Colors.transparent : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                image: n.senderPhoto != null 
                    ? DecorationImage(image: NetworkImage(n.senderPhoto!), fit: BoxFit.cover)
                    : null,
              ),
              child: n.senderPhoto == null 
                  ? Icon(_getIcon(n.title), color: iconColor, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead ? FontWeight.bold : FontWeight.w900, 
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600], 
                      fontSize: 14,
                      fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getTimeAgo(n.timestamp),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),

            // Unread Dot
            if (!n.isRead)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.5), blurRadius: 4)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dateTime);
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('All clear!', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  IconData _getIcon(String title) {
    if (title.contains('Task Assigned')) return Icons.assignment_outlined;
    if (title.contains('Completed')) return Icons.check_circle_outline;
    if (title.contains('Comment')) return Icons.chat_bubble_outline;
    return Icons.notifications_none;
  }

  Color _getIconColor(String title) {
    if (title.contains('Task Assigned')) return Colors.blue;
    if (title.contains('Completed')) return Colors.green;
    if (title.contains('Comment')) return Colors.orange;
    return Colors.purple;
  }

  void _navigateToTask(BuildContext context, String taskId) async {
    // Show a small loading indicator if needed
    final db = DatabaseService();
    final task = await db.getTaskById(taskId);
    
    if (task != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task no longer exists.')),
      );
    }
  }
}
