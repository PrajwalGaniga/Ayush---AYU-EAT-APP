import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';

class CameraScreen extends StatefulWidget {
  final String userPhone;
  const CameraScreen({super.key, required this.userPhone});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Map<String, dynamic>? _analysisResult;
  bool _isAnalyzing = false;

  // FIXED: Explicit Helper for Data Chips
  Widget _buildPropertyChip(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AyuTheme.darkGreen, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      _imageFile = File(image.path);
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.scanMeal));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var res = await http.Response.fromStream(await request.send());

      if (res.statusCode == 200) {
        setState(() => _analysisResult = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Scan Error: $e");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Vaidya Lens"), backgroundColor: Colors.transparent, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imageFile != null) Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                    if (_isAnalyzing) const CircularProgressIndicator(color: Colors.white),
                    if (_imageFile == null) const Icon(Icons.center_focus_weak, color: Colors.white38, size: 80),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
              child: _analysisResult == null ? _buildInitialUI() : _buildAnalysisList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Scan Meal for Ayush Insight", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionBtn("CAMERA", Icons.camera_alt, () => _processImage(ImageSource.camera)),
            _actionBtn("GALLERY", Icons.photo_library, () => _processImage(ImageSource.gallery)),
          ],
        )
      ],
    );
  }

  Widget _buildAnalysisList() {
    final List items = _analysisResult!['items'] ?? [];
    final List warnings = _analysisResult!['warnings'] ?? [];

    return ListView(
      children: [
        const Text("Diagnostic Composition", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        const Divider(),
        ...items.map((item) => ListTile(
          leading: const Icon(Icons.check_circle, color: AyuTheme.darkGreen),
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(item['dosha']),
          trailing: Text(item['virya'], style: const TextStyle(color: Colors.grey)),
        )),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text("VIRUDDHA WARNINGS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ...warnings.map((w) => Card(
            color: Colors.red[50],
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: Text(w['reason'], style: const TextStyle(fontSize: 13, color: Colors.red)),
            ),
          )),
        ],
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => setState(() => _analysisResult = null), child: const Text("NEW SCAN")),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback tap) {
    return ElevatedButton.icon(onPressed: tap, icon: Icon(icon), label: Text(label));
  }
}