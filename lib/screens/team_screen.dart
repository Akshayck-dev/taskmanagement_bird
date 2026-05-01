import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import 'home_screens.dart';

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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Text(
                'Team Members',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: dbService.getAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data?.where((u) => u.name.toLowerCase().contains(_searchQuery)).toList() ?? [];
                  
                  if (users.isEmpty) {
                    return Center(
                      child: Text('No members found', style: GoogleFonts.inter(color: Colors.grey)),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Column(
                        children: [
                          ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => MemberDetailScreen(user: user)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(user.photoUrl),
                            ),
                            title: Text(
                              user.name,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              user.email,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                          ),
                          Divider(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), height: 1),
                        ],
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

class MemberDetailScreen extends StatelessWidget {
  final AppUser user;
  const MemberDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(user.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold)), elevation: 0),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Column(
              children: [
                CircleAvatar(radius: 50, backgroundImage: NetworkImage(user.photoUrl)),
                const SizedBox(height: 16),
                Text(user.name, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800)),
                Text(user.email, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Assigned Tasks',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: dbService.getTasks(user.uid),
              builder: (context, snapshot) {
                final tasks = snapshot.data?.where((t) => t.assignedTo == user.uid).toList() ?? [];
                if (tasks.isEmpty) {
                  return Center(child: Text('No tasks assigned yet', style: GoogleFonts.inter(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return ListTile(
                      title: Text(
                        task.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      subtitle: Text(
                        'Due: ${DateFormat('MMM d').format(task.deadline)}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: Icon(
                        task.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: task.isDone ? Colors.green : Colors.grey,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
