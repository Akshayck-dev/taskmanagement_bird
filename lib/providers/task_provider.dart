import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/app_models.dart';

class TaskProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  
  // You can add local state here if needed, 
  // but mostly we'll use StreamProvider in main.dart 
  // to directly provide streams to the UI.
}
