import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final String userPhone;
  const OnboardingScreen({super.key, required this.userPhone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  List<int> userAnswers = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _quiz = [
  {"q": "How is your body frame?", "o": ["Thin/Bony (Vata)", "Medium/Athletic (Pitta)", "Large/Stocky (Kapha)"]},
  {"q": "Skin Texture & Temperature?", "o": ["Dry/Rough/Cold (Vata)", "Oily/Warm/Reddish (Pitta)", "Thick/Soft/Cool (Kapha)"]},
  {"q": "Your Digestive Pattern (Agni)?", "o": ["Irregular/Gas (Vata)", "Strong/Sharp Hunger (Pitta)", "Slow/Heavy Feeling (Kapha)"]},
  {"q": "Sleep Quality?", "o": ["Light/Interrupted (Vata)", "Moderate/Sound (Pitta)", "Deep/Long/Heavy (Kapha)"]},
  {"q": "Speech & Movement?", "o": ["Fast/Talkative/Anxious (Vata)", "Purposeful/Sharp/Direct (Pitta)", "Slow/Steady/Calm (Kapha)"]},
  {"q": "Response to Stress?", "o": ["Fear/Worry (Vata)", "Anger/Irritation (Pitta)", "Withdrawal/Calm (Kapha)"]},
  {"q": "Mental Focus?", "o": ["Quick to learn, quick to forget (Vata)", "Focused/Intelligent (Pitta)", "Slow to learn, remembers forever (Kapha)"]},
  {"q": "Elimination (Stool)?", "o": ["Hard/Constipated (Vata)", "Soft/Loose/Frequent (Pitta)", "Heavy/Solid/Regular (Kapha)"]},
];

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.updatePrakriti}/${widget.userPhone}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"answers": userAnswers}),
      );

      if (response.statusCode == 200) {
  if (mounted) {
    // Quiz complete! Now send them to the personalized home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (c) => DashboardScreen(userPhone: widget.userPhone)),
    );
  }
}
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Prakriti Analysis"), backgroundColor: AyuTheme.darkGreen),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildReportStep(),
              ..._quiz.map((q) => _buildQuizPage(q)).toList(),
            ],
          ),
    );
  }

  Widget _buildReportStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.note_add_outlined, size: 80, color: AyuTheme.darkGreen),
        const Text("Clinical Report Upload", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("Already have a Prakriti report from a Vaidya? Upload it here to skip the quiz."),
        ),
        ElevatedButton(
          onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease), 
          child: const Text("Upload PDF/Image")
        ),
        TextButton(
          onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease), 
          child: const Text("Skip to Digital Quiz")
        ),
      ],
    );
  }

  Widget _buildQuizPage(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data['q'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AyuTheme.darkGreen)),
          const SizedBox(height: 30),
          ...List.generate(3, (i) => Card(
            child: ListTile(
              title: Text(data['o'][i]),
              onTap: () {
                userAnswers.add(i);
                if (userAnswers.length == _quiz.length) {
                  _submit();
                } else {
                  _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                }
              },
            ),
          )),
        ],
      ),
    );
  }
}