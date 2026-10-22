import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../services/theme_provider.dart';
import '../widgets/app_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

                  // Gradient profile hero
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: kBrandGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D5DF6).withValues(alpha: 0.32),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                                  backgroundImage: _imageFile != null
                                      ? FileImage(_imageFile!)
                                      : (userData.photoUrl.isNotEmpty ? CachedNetworkImageProvider(userData.photoUrl) : null) as ImageProvider?,
                                  child: (_imageFile == null && userData.photoUrl.isEmpty)
                                      ? Text(
                                          userData.name.isNotEmpty ? userData.name[0].toUpperCase() : '?',
                                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Icon(Icons.camera_alt_rounded, size: 14, color: primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          userData.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userData.email,
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                        if (userData.designation.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              userData.designation,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

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
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
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
                          color: Colors.redAccent.withValues(alpha: 0.2),
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
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          AnimatedCount(
            value: int.tryParse(value) ?? 0,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
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

