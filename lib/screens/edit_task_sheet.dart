import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';
import '../widgets/app_widgets.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class EditTaskBottomSheet extends StatefulWidget {
  final TaskModel task;
  const EditTaskBottomSheet({super.key, required this.task});

  @override
  State<EditTaskBottomSheet> createState() => _EditTaskBottomSheetState();
}

class _EditTaskBottomSheetState extends State<EditTaskBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedCategory;
  late String _selectedPriority;
  late DateTime _selectedDeadline;
  bool _isLoading = false;
  File? _taskImage;
  String? _audioPath;
  bool _isRecording = false;
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/task_audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint("Error stopping recording: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() => _taskImage = File(image.path));
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _selectedCategory = widget.task.category;
    _selectedPriority = widget.task.priority;
    _selectedDeadline = widget.task.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF7A7A7A))),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildChip(String label, bool isSelected, Function() onTap, Color activeColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Colors.grey[400]!),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600], 
            fontWeight: FontWeight.bold, 
            fontSize: 12
          )
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24, 
        top: 20, 
        left: 24, 
        right: 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[isDark ? 800 : 300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Task', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildFieldLabel('Title'),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontWeight: FontWeight.w500),
              decoration: _inputDecoration('Task title...', isDark),
            ),
            const SizedBox(height: 20),
            
            _buildFieldLabel('Description'),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDecoration('Task description...', isDark),
            ),
            
            _buildFieldLabel('Deadline'),
            GestureDetector(
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDeadline,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate != null && mounted) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDeadline),
                  );
                  setState(() {
                    _selectedDeadline = DateTime(
                      pickedDate.year, pickedDate.month, pickedDate.day, 
                      pickedTime?.hour ?? 18, pickedTime?.minute ?? 0,
                    );
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 20, color: primaryColor),
                    const SizedBox(width: 12),
                    Text(DateFormat('MMM d, yyyy - h:mm a').format(_selectedDeadline), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildFieldLabel('Priority'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TaskPriorities.all.map((pr) => taskOptionChip(
                label: pr,
                selected: _selectedPriority == pr,
                onTap: () => setState(() => _selectedPriority = pr),
                isDark: isDark,
                primaryColor: primaryColor,
              )).toList(),
            ),
            const SizedBox(height: 16),

            _buildFieldLabel('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TaskCategories.all.map((cat) => taskOptionChip(
                label: cat,
                selected: _selectedCategory == cat,
                onTap: () => setState(() => _selectedCategory = cat),
                isDark: isDark,
                primaryColor: primaryColor,
              )).toList(),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFieldLabel("Attachment"),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary, size: 24),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  onSelected: (value) {
                    if (value == "camera") _pickImage(ImageSource.camera);
                    if (value == "gallery") _pickImage(ImageSource.gallery);
                    if (value == "audio") _isRecording ? _stopRecording() : _startRecording();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: "camera", child: Row(children: [const Icon(Icons.camera_alt_outlined, size: 20), const SizedBox(width: 12), const Text("Camera")])),
                    PopupMenuItem(value: "gallery", child: Row(children: [const Icon(Icons.image_outlined, size: 20), const SizedBox(width: 12), const Text("Gallery")])),
                    PopupMenuItem(value: "audio", child: Row(children: [Icon(_isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded, size: 20, color: _isRecording ? Colors.red : null), const SizedBox(width: 12), Text(_isRecording ? "Stop Recording" : "Record Audio")])),
                  ],
                ),
              ],
            ),
            if (_taskImage != null || _audioPath != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_taskImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_taskImage!, height: 80, width: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _taskImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_audioPath != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.audiotrack_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text("Audio Recording", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _audioPath = null),
                            child: Icon(Icons.close, size: 14, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            
            if (widget.task.updatedAt != null) ...[
              Center(
                child: Text(
                  'Last edited at: ${DateFormat('MMM d, h:mm a').format(widget.task.updatedAt!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            GestureDetector(
              onTap: _isLoading ? null : () async {
                if (_titleController.text.trim().isEmpty) return;
                if (_isRecording) await _stopRecording();
                setState(() => _isLoading = true);
                
                try {
                  final dbService = DatabaseService();
                  String? imageUrl;
                  String? audioUrl;
                  
                  final List<Future> uploads = [];
                  if (_taskImage != null && await _taskImage!.exists()) {
                    uploads.add(dbService.uploadTaskImage(_taskImage!).then((url) => imageUrl = url));
                  }
                  if (_audioPath != null && await File(_audioPath!).exists()) {
                    uploads.add(dbService.uploadTaskAudio(File(_audioPath!)).then((url) => audioUrl = url));
                  }
                  
                  if (uploads.isNotEmpty) {
                    await Future.wait(uploads).timeout(const Duration(seconds: 60));
                  }
                  
                  await dbService.updateTaskDetails(
                    widget.task.id,
                    _titleController.text.trim(),
                    _descController.text.trim(),
                    _selectedCategory,
                    _selectedPriority,
                    _selectedDeadline,
                    imageUrl: imageUrl,
                    audioUrl: audioUrl,
                  );
                  
                  if (mounted) {
                    setState(() => _isLoading = false);
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Center(
                  child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
