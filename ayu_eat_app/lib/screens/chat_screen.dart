import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Required for handling TimeoutException
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';

class AyushChatScreen extends StatefulWidget {
  final String userPhone;
  const AyushChatScreen({super.key, required this.userPhone});

  @override
  State<AyushChatScreen> createState() => _AyushChatScreenState();
}

class _AyushChatScreenState extends State<AyushChatScreen> {
  final ScrollController _scrollController = ScrollController();
  String _currentLang = "en";
  String _currentNode = "AGNI_START"; 
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isWakingUp = false; // New: Tracks Render cold start

  @override
  void initState() {
    super.initState();
    // Start the conversation immediately
    _fetchNextStep(null);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- CORE LOGIC: REWRITTEN FOR PRODUCTION RELIABILITY ---
  Future<void> _fetchNextStep(String? choice) async {
    setState(() {
      _isTyping = true;
      _isWakingUp = false;
    });

    try {
      // 1. URL Safety: Prevent // double-slash errors
      final String base = ApiConfig.baseUrl.endsWith('/') 
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1) 
          : ApiConfig.baseUrl;
      final String fullUrl = "$base/chat_query";

      debugPrint("📡 Chat Request to: $fullUrl");

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "current_node": _currentNode,
          "user_choice": choice,
          "lang": _currentLang,
          "phone": widget.userPhone
        }),
      ).timeout(const Duration(seconds: 40)); // 40s is critical for Render Free Tier

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;

        setState(() {
          if (data['type'] == 'question') {
            _messages.add({
              "sender": "bot", 
              "text": data['question'], 
              "options": data['options'],
              "time": DateTime.now()
            });
            _currentNode = data['node_id'];
          } else {
            // Assessment Result reached
            _messages.add({
              "sender": "bot", 
              "text": data['data']['message'], 
              "isResult": true,
              "time": DateTime.now()
            });
          }
          _isTyping = false;
        });
        _scrollToBottom();
      } else {
        _showErrorSnack("Server Error (${response.statusCode}). Please retry.");
      }
    } on TimeoutException {
      // Specifically handle Render's sleep mode
      setState(() => _isWakingUp = true);
      _showErrorSnack("Server is waking up. This usually takes 30 seconds on the first load.");
    } catch (e) {
      debugPrint("🚨 CHAT ERROR: $e");
      _showErrorSnack("Connection lost. Please check your internet.");
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: "Retry", onPressed: () => _fetchNextStep(null)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("Digital Vaidya", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AyuTheme.darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _messages.clear();
                _currentNode = "AGNI_START";
              });
              _fetchNextStep(null);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ActionChip(
              backgroundColor: Colors.white24,
              label: Text(_currentLang == "en" ? "ಕನ್ನಡ" : "ENG", style: const TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() {
                  _currentLang = _currentLang == "en" ? "kn" : "en";
                  _messages.clear(); 
                  _currentNode = "AGNI_START";
                });
                _fetchNextStep(null);
              },
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_isTyping
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _buildMessageLayout(_messages[i]),
                  ),
          ),
          if (_isTyping) _buildTypingIndicator(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          const Text("Waiting for Vaidya...", style: TextStyle(color: Colors.grey)),
          TextButton(onPressed: () => _fetchNextStep(null), child: const Text("Tap to Wake Up Server"))
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 15, height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: AyuTheme.darkGreen),
          ),
          const SizedBox(width: 12),
          Text(
            _isWakingUp ? "Server is waking up (Render Cold Start)..." : "Vaidya is thinking...",
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- UI BUBBLE BUILDERS (Simplified for clarity) ---
  Widget _buildMessageLayout(Map<String, dynamic> msg) {
    bool isBot = msg['sender'] == "bot";
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Align(
        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
        child: _buildMessageBubble(msg),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isBot = msg['sender'] == "bot";
    bool isResult = msg['isResult'] ?? false;

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isResult ? Colors.orange.shade50 : (isBot ? Colors.white : AyuTheme.darkGreen),
        borderRadius: BorderRadius.circular(18),
        border: isResult ? Border.all(color: Colors.orange) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg['text'], style: TextStyle(color: isBot ? Colors.black87 : Colors.white)),
          if (msg['options'] != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (msg['options'] as List).map((opt) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AyuTheme.darkGreen,
                  side: const BorderSide(color: AyuTheme.darkGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
                onPressed: () {
                  setState(() => _messages.add({"sender": "user", "text": opt['label']}));
                  _fetchNextStep(opt['value']);
                },
                child: Text(opt['label'], style: const TextStyle(fontSize: 12)),
              )).toList(),
            ),
          ]
        ],
      ),
    );
  }
}