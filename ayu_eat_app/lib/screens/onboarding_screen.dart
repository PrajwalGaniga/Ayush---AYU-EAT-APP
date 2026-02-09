import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
  int _currentStep = 0;
  bool _isLoading = false;

  // 1. DATA CONTAINERS: Capturing the full clinical intake
  final List<int> _quizAnswers = [];
  final List<String> _selectedConditions = [];
  final List<String> _selectedAllergies = [];
  final TextEditingController _weightController = TextEditingController();
  String _activityLevel = "Moderate";

  // 2. CLINICAL MASTER DATA
  final List<String> _conditions = ["Diabetes", "Hypertension", "Acid Reflux", "PCOS", "Asthma", "Cholesterol"];
  final List<String> _allergies = ["Peanuts", "Dairy", "Gluten", "Soy", "Shellfish", "None"];

  final List<Map<String, dynamic>> _quiz = [
    {
      "q": "How is your body frame?", 
      "o": ["Thin/Bony (Vata)", "Medium/Athletic (Pitta)", "Large/Stocky (Kapha)"]
    },
    {
      "q": "Skin Texture & Temperature?", 
      "o": ["Dry/Rough/Cold (Vata)", "Oily/Warm/Reddish (Pitta)", "Thick/Soft/Cool (Kapha)"]
    },
    {
      "q": "Your Digestive Pattern (Agni)?", 
      "o": ["Irregular/Gas (Vata)", "Strong/Sharp Hunger (Pitta)", "Slow/Heavy Feeling (Kapha)"]
    },
    {
      "q": "Response to Stress?", 
      "o": ["Fear/Worry (Vata)", "Anger/Irritation (Pitta)", "Withdrawal/Calm (Kapha)"]
    },
  ];

  // 3. SUBMIT LOGIC: Consolidates Quiz + Medical Profile
  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final String url = "${ApiConfig.baseUrl}/update_onboarding/${widget.userPhone}";

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "quiz_answers": _quizAnswers,
          "health_profile": {
            "conditions": _selectedConditions,
            "allergies": _selectedAllergies,
            "weight": _weightController.text,
            "activity_level": _activityLevel
          }
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => DashboardScreen(userPhone: widget.userPhone)),
        );
      } else {
        _showError("Sync failed (${response.statusCode}). Please check your connection.");
      }
    } on TimeoutException {
      _showError("Server took too long to respond. Please try again.");
    } catch (e) {
      _showError("Network Error: Could not reach the Vaidya server.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AyuTheme.warningRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text("Health Onboarding", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AyuTheme.darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AyuTheme.darkGreen))
          : Column(
        children: [
          // Visual progress feedback for high-impact UX
          LinearProgressIndicator(
            value: (_currentStep + 1) / (3 + _quiz.length),
            backgroundColor: Colors.grey[200],
            color: AyuTheme.lightGreen,
            minHeight: 6,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentStep = i),
              children: [
                _buildReportStep(),
                _buildMedicalProfileStep(),
                _buildPhysicalMetricsStep(),
                ..._quiz.map((q) => _buildQuizPage(q)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI STEPS: MODULAR BUILDERS ---

  Widget _buildReportStep() {
    return _buildContainer(
      icon: Icons.upload_file_rounded,
      title: "Clinical Report",
      subtitle: "Upload an existing Prakriti report from a Vaidya to skip the digital quiz.",
      child: Column(
        children: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
              child: const Text("UPLOAD PDF/IMAGE")
          ),
          const SizedBox(height: 10),
          TextButton(
              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
              child: const Text("Skip to Digital Analysis", style: TextStyle(color: AyuTheme.darkGreen))
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalProfileStep() {
    return _buildContainer(
      icon: Icons.medical_services_outlined,
      title: "Medical Profile",
      subtitle: "Your AI recipes will be adjusted based on these conditions.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Existing Conditions", style: TextStyle(fontWeight: FontWeight.bold, color: AyuTheme.darkGreen)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _conditions.map((c) => FilterChip(
              label: Text(c),
              selected: _selectedConditions.contains(c),
              onSelected: (val) => setState(() => val ? _selectedConditions.add(c) : _selectedConditions.remove(c)),
              selectedColor: AyuTheme.lightGreen.withOpacity(0.3),
              checkmarkColor: AyuTheme.darkGreen,
            )).toList(),
          ),
          const SizedBox(height: 25),
          const Text("Food Allergies", style: TextStyle(fontWeight: FontWeight.bold, color: AyuTheme.darkGreen)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _allergies.map((a) => FilterChip(
              label: Text(a),
              selected: _selectedAllergies.contains(a),
              onSelected: (val) => setState(() => val ? _selectedAllergies.add(a) : _selectedAllergies.remove(a)),
              selectedColor: AyuTheme.lightGreen.withOpacity(0.3),
              checkmarkColor: AyuTheme.darkGreen,
            )).toList(),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
              child: const Text("CONTINUE")
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalMetricsStep() {
    return _buildContainer(
      icon: Icons.monitor_weight_outlined,
      title: "Physical Metrics",
      subtitle: "This helps the Vaidya AI calculate proper nutrient intensity.",
      child: Column(
        children: [
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Current Weight (kg)", 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.scale),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _activityLevel,
            decoration: InputDecoration(
              labelText: "Activity Level", 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.directions_run),
            ),
            items: ["Sedentary", "Moderate", "Active", "Athlete"].map((l) =>
                DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (val) => setState(() => _activityLevel = val!),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
              child: const Text("START PRAKRITI QUIZ")
          ),
        ],
      ),
    );
  }

  Widget _buildQuizPage(Map<String, dynamic> data) {
    return _buildContainer(
        title: "Prakriti Quiz",
        subtitle: data['q'],
        child: Column(
          children: List.generate(3, (i) => Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Text(data['o'][i], style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AyuTheme.darkGreen),
              onTap: () {
                _quizAnswers.add(i);
                if (_quizAnswers.length == _quiz.length) {
                  _submit();
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300), 
                    curve: Curves.ease,
                  );
                }
              },
            ),
          )),
        ), // Fixed: Column closed
    ); // Fixed: _buildContainer closed
  }

  // --- SHARED WRAPPER COMPONENT ---
  Widget _buildContainer({IconData? icon, required String title, required String subtitle, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 70, color: AyuTheme.darkGreen),
            const SizedBox(height: 10),
          ],
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AyuTheme.darkGreen)),
          const SizedBox(height: 12),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.4)),
          const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }
}