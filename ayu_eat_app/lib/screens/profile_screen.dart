import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';

class ProfileScreen extends StatefulWidget {
  final String userPhone;
  const ProfileScreen({super.key, required this.userPhone});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Data Containers
  String _fullname = "Loading...";
  String _prakriti = "Unknown";
  String _agni = "Sama Agni";
  List<String> _selectedConditions = [];
  List<String> _selectedAllergies = [];
  final TextEditingController _weightController = TextEditingController();
  String _activityLevel = "Moderate";
  bool _reportUploaded = false;

  // Master Lists
  final List<String> _conditions = ["Diabetes", "Hypertension", "Acid Reflux", "PCOS", "Asthma", "Cholesterol"];
  final List<String> _allergies = ["Peanuts", "Dairy", "Gluten", "Soy", "Shellfish", "None"];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // 1. Initial Data Load
  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/user_profile/${widget.userPhone}"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final health = data['health_profile'] ?? {};
        
        setState(() {
          _fullname = data['fullname'];
          _prakriti = data['prakriti']['dominant'];
          _selectedConditions = List<String>.from(health['conditions'] ?? []);
          _selectedAllergies = List<String>.from(health['allergies'] ?? []);
          _weightController.text = health['weight'] ?? "";
          _activityLevel = health['activity_level'] ?? "Moderate";
          _reportUploaded = data['report_uploaded'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError("Failed to sync with Vaidya Server.");
    }
  }

  // 2. Profile Update Logic
  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/update_profile/${widget.userPhone}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "conditions": _selectedConditions,
          "allergies": _selectedAllergies,
          "weight": _weightController.text,
          "activity_level": _activityLevel,
          "report_uploaded": _reportUploaded
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Health Profile Synchronized ✅"), backgroundColor: AyuTheme.darkGreen)
        );
      }
    } catch (e) {
      _showError("Update failed. Check connection.");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.redAccent));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        title: const Text("Vaidya Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AyuTheme.darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving) 
            const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          else
            IconButton(icon: const Icon(Icons.save_rounded), onPressed: _updateProfile)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AyuTheme.darkGreen))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildIdentityHeader(),
              const SizedBox(height: 25),
              _buildMedicalSection(),
              const SizedBox(height: 25),
              _buildMetricsSection(),
              const SizedBox(height: 25),
              _buildReportSection(),
            ],
          ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildIdentityHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        children: [
          const CircleAvatar(radius: 35, backgroundColor: AyuTheme.lightGreen, child: Icon(Icons.person_outline, size: 40, color: AyuTheme.darkGreen)),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fullname, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("Dominant Dosha: $_prakriti", style: const TextStyle(color: AyuTheme.darkGreen, fontWeight: FontWeight.w600)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMedicalSection() {
    return _buildSectionCard(
      title: "Medical Profile",
      icon: Icons.medical_information_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Existing Conditions", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _conditions.map((c) => FilterChip(
              label: Text(c, style: TextStyle(fontSize: 12, color: _selectedConditions.contains(c) ? Colors.white : Colors.black)),
              selected: _selectedConditions.contains(c),
              selectedColor: AyuTheme.darkGreen,
              onSelected: (val) => setState(() => val ? _selectedConditions.add(c) : _selectedConditions.remove(c)),
            )).toList(),
          ),
          const SizedBox(height: 20),
          const Text("Food Allergies", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _allergies.map((a) => FilterChip(
              label: Text(a, style: TextStyle(fontSize: 12, color: _selectedAllergies.contains(a) ? Colors.white : Colors.black)),
              selected: _selectedAllergies.contains(a),
              selectedColor: Colors.orangeAccent,
              onSelected: (val) => setState(() => val ? _selectedAllergies.add(a) : _selectedAllergies.remove(a)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return _buildSectionCard(
      title: "Physical Metrics",
      icon: Icons.monitor_weight_rounded,
      child: Column(
        children: [
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Weight (kg)", prefixIcon: Icon(Icons.scale)),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _activityLevel,
            decoration: const InputDecoration(labelText: "Activity Level", prefixIcon: Icon(Icons.run_circle_outlined)),
            items: ["Sedentary", "Moderate", "Active", "Athlete"].map((l) => 
              DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (val) => setState(() => _activityLevel = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection() {
    return _buildSectionCard(
      title: "Diagnostic Reports",
      icon: Icons.upload_file_rounded,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_reportUploaded ? "Latest Report Linked" : "No Report Found"),
        subtitle: const Text("Add clinical reports to improve AI accuracy"),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _reportUploaded ? Colors.blueGrey : AyuTheme.darkGreen),
          onPressed: () => setState(() => _reportUploaded = true), // Simulated upload
          child: Text(_reportUploaded ? "UPDATE" : "UPLOAD"),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: AyuTheme.darkGreen), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const Divider(height: 30),
          child,
        ],
      ),
    );
  }
}