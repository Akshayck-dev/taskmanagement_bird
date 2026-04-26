import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import 'home_screens.dart'; // To navigate to TaskDetailScreen

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Team Members',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search Bar (Like Customer Section)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
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
                  return const Center(child: Text('No members found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: users.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    height: 40,
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MemberDetailScreen(user: user)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: NetworkImage(user.photoUrl),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
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

// Detailed view for a member (Shows their tasks)
class MemberDetailScreen extends StatelessWidget {
  final AppUser user;
  const MemberDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(title: Text(user.name), elevation: 0),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                CircleAvatar(radius: 50, backgroundImage: NetworkImage(user.photoUrl)),
                const SizedBox(height: 16),
                Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(user.email, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Assigned Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: dbService.getTasks(user.uid),
              builder: (context, snapshot) {
                final tasks = snapshot.data?.where((t) => t.assignedTo == user.uid).toList() ?? [];
                if (tasks.isEmpty) return const Center(child: Text('No tasks assigned yet.'));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return ListTile(
                      title: Text(task.title, style: TextStyle(decoration: task.isDone ? TextDecoration.lineThrough : null)),
                      subtitle: Text('Due: ${task.deadline.day}/${task.deadline.month}'),
                      trailing: Icon(task.isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: task.isDone ? Colors.green : Colors.grey),
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
