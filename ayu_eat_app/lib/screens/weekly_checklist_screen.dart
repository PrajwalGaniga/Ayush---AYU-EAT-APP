import 'dart:async'; // Required for robust network handling
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';
import '../services/local_storage.dart';

class WeeklyChecklistScreen extends StatefulWidget {
  final String userPhone;
  final Map<String, dynamic>? prakriti;

  const WeeklyChecklistScreen({
    super.key, 
    required this.userPhone, 
    this.prakriti,
  });

  @override
  State<WeeklyChecklistScreen> createState() => _WeeklyChecklistScreenState();
}

class _WeeklyChecklistScreenState extends State<WeeklyChecklistScreen> {
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  String _lang = "en"; 
  int _ojasScore = 0;
  int _currentDay = 1;
  late String _dominantDosha;

  @override
  void initState() {
    super.initState();
    // Senior Dev Tip: Initialize UI state from passed data to avoid layout jumps
    _dominantDosha = widget.prakriti?['dominant'] ?? "Vata";
    _fetchUserTasks();
  }

  // Clinical Logic: Contextual reasoning for the user
  String _getDoshaReason() {
    final Map<String, String> reasons = {
      "Vata": _lang == "en" 
          ? "Rituals to ground your airy nature and stabilize the nervous system."
          : "ಈ ಆಚರಣೆಗಳು ನಿಮ್ಮ ಚಂಚಲ ಮನಸ್ಸನ್ನು ಶಾಂತಗೊಳಿಸುತ್ತವೆ ಮತ್ತು ನರಮಂಡಲವನ್ನು ಸ್ಥಿರಗೊಳಿಸುತ್ತವೆ.",
      "Pitta": _lang == "en"
          ? "Cooling tasks to manage internal heat and digestive intensity."
          : "ಈ ಕಾರ್ಯಗಳು ನಿಮ್ಮ ಆಂತರಿಕ ಉಷ್ಣತೆಯನ್ನು ತಂಪಾಗಿಸುತ್ತವೆ ಮತ್ತು ಜೀರ್ಣಕ್ರಿಯೆಯನ್ನು ನಿರ್ವಹಿಸುತ್ತವೆ.",
      "Kapha": _lang == "en"
          ? "Stimulating exercises to clear sluggishness and boost metabolism."
          : "ಈ ವ್ಯಾಯಾಮಗಳು ದೇಹದಿಂದ ಆಲಸ್ಯವನ್ನು ಹೋಗಲಾಡಿಸುತ್ತವೆ ಮತ್ತು ಚಯಾಪಚಯವನ್ನು ಹೆಚ್ಚಿಸುತ್ತವೆ."
    };
    return reasons[_dominantDosha] ?? reasons["Vata"]!;
  }

  // Type-Safe Icon Helper: Handles both String and Int IDs
  IconData _getTaskIcon(dynamic taskId) {
    final String idStr = taskId.toString();
    if (idStr.contains('1')) return Icons.wb_sunny_outlined;
    if (idStr.contains('2')) return Icons.spa;
    if (idStr.contains('3')) return Icons.water_drop;
    if (idStr.contains('4')) return Icons.air;
    if (idStr.contains('5')) return Icons.nature_people;
    if (idStr.contains('6')) return Icons.restaurant;
    return Icons.nights_stay;
  }

  Future<void> _fetchUserTasks() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.userProfile(widget.userPhone)))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // SAVE TO CACHE
        await LocalCache.save("checklist_${widget.userPhone}", data);
        
        if (mounted) {
          setState(() {
            _tasks = data['data']['weekly_tasks'] ?? [];
            _ojasScore = data['data']['ojas_score'] ?? 0;
            _currentDay = data['data']['current_day'] ?? 1;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Offline mode: Loading cached rituals.");
    }

    // FALLBACK: Load from Cache
    final cached = await LocalCache.get("checklist_${widget.userPhone}");
    if (mounted && cached != null) {
      setState(() {
        _tasks = cached['data']['weekly_tasks'] ?? [];
        _ojasScore = cached['data']['ojas_score'] ?? 0;
        _currentDay = cached['data']['current_day'] ?? 1;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Optimistic UI Update: Makes the app feel incredibly fast
  Future<void> _updateTask(dynamic taskId, bool isDone) async {
    final String idStr = taskId.toString();
    
    setState(() {
      final task = _tasks.firstWhere((t) => t['id'].toString() == idStr);
      task['done'] = isDone;
      _ojasScore += isDone ? 8 : -8; 
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/update_task/${widget.userPhone}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"taskId": taskId, "isDone": isDone}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) throw Exception("Failed to sync");
      _fetchUserTasks(); // Background sync for server-side timestamps
    } catch (e) {
      _fetchUserTasks(); // Rollback on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sync failed. Checking connection...")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(
        elevation: 0,
        title: Text(_lang == "en" ? "Day $_currentDay Rituals" : "ದಿನ $_currentDay ಆಚರಣೆಗಳು"),
        backgroundColor: AyuTheme.darkGreen,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => setState(() => _lang = _lang == "en" ? "kn" : "en"),
            child: Text(_lang == "en" ? "ಕನ್ನಡ" : "ENG", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AyuTheme.darkGreen))
          : Column(
              children: [
                _buildOjasHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _tasks.length,
                    itemBuilder: (context, i) => _buildTaskCard(_tasks[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOjasHeader() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: AyuTheme.darkGreen,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_lang == "en" ? "Ojas Vitality" : "ಓಜಸ್ ಶಕ್ತಿ", 
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("$_ojasScore / 100", 
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text(_dominantDosha, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _getDoshaReason(), 
            style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 13, height: 1.4), 
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isDone = task['done'] ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone ? AyuTheme.darkGreen.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDone ? AyuTheme.darkGreen : Colors.grey.shade200),
      ),
      child: CheckboxListTile(
        activeColor: AyuTheme.darkGreen,
        contentPadding: const EdgeInsets.all(12),
        secondary: CircleAvatar(
          backgroundColor: isDone ? AyuTheme.darkGreen : Colors.grey.shade100,
          child: Icon(_getTaskIcon(task['id']), color: isDone ? Colors.white : Colors.grey),
        ),
        title: Text(
          _lang == "en" ? task['task_en'] : task['task_kn'], 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDone ? AyuTheme.darkGreen : Colors.black87,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_lang == "en" ? task['desc_en'] : task['desc_kn'], 
              style: const TextStyle(fontSize: 12, height: 1.3)),
            if (isDone && task['completed_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text("🕒 ${task['completed_at']}", 
                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        value: isDone,
        onChanged: (val) => _updateTask(task['id'], val!),
      ),
    );
  }
}