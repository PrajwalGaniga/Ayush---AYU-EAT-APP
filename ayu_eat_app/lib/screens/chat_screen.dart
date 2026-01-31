import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  String _currentNode = "AGNI_Q1"; 
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _fetchNextStep(null);
  }

  // Smooth scroll to the latest message
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

  Future<void> _fetchNextStep(String? choice) async {
    setState(() => _isTyping = true);
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/chat_query"), // Uses global config
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "current_node": _currentNode,
          "user_choice": choice,
          "lang": _currentLang,
          "phone": widget.userPhone
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
            // Conclusion Logic
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
      }
    } catch (e) {
      debugPrint("Chat Error: $e");
      setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Digital Vaidya Chat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("AI Health Assessment", style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: AyuTheme.darkGreen,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ActionChip(
              backgroundColor: Colors.white24,
              label: Text(_currentLang == "en" ? "ಕನ್ನಡ" : "ENG", style: const TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() {
                  _currentLang = _currentLang == "en" ? "kn" : "en";
                  _messages.clear(); 
                  _currentNode = "AGNI_Q1";
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
            child: ListView.builder(
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

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.all(15),
      alignment: Alignment.centerLeft,
      child: const Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: AyuTheme.accentSage, child: Icon(Icons.psychology, size: 14, color: Colors.white)),
          SizedBox(width: 10),
          Text("Vaidya is thinking...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMessageLayout(Map<String, dynamic> msg) {
    bool isBot = msg['sender'] == "bot";
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot) ...[
            const CircleAvatar(radius: 16, backgroundColor: AyuTheme.darkGreen, child: Icon(Icons.person, size: 18, color: Colors.white)),
            const SizedBox(width: 10),
          ],
          _buildMessageBubble(msg),
          if (!isBot) ...[
            const SizedBox(width: 10),
            const CircleAvatar(radius: 16, backgroundColor: Colors.blueGrey, child: Icon(Icons.account_circle, size: 18, color: Colors.white)),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isBot = msg['sender'] == "bot";
    bool isResult = msg['isResult'] ?? false;

    return Flexible(
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isResult 
                  ? Colors.orange.withOpacity(0.05) 
                  : (isBot ? Colors.white : AyuTheme.darkGreen),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(isBot ? 0 : 15),
                bottomRight: Radius.circular(isBot ? 15 : 0),
              ),
              border: isResult ? Border.all(color: Colors.orange, width: 2) : null,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isResult) 
                  const Row(
                    children: [
                      Icon(Icons.assignment_turned_in, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text("VAIDYA REPORT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 10)),
                    ],
                  ),
                const SizedBox(height: 5),
                Text(msg['text'], style: TextStyle(color: isBot ? Colors.black87 : Colors.white, height: 1.4)),
              ],
            ),
          ),
          if (msg['options'] != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (msg['options'] as List).map((opt) => ActionChip(
                backgroundColor: Colors.white,
                shape: const StadiumBorder(side: BorderSide(color: AyuTheme.darkGreen)),
                label: Text(opt['label'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AyuTheme.darkGreen)),
                onPressed: () {
                  setState(() => _messages.add({"sender": "user", "text": opt['label']}));
                  _fetchNextStep(opt['value']);
                },
              )).toList(),
            ),
          ]
        ],
      ),
    );
  }
}