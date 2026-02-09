import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';

enum ScanStage { capture, detection, audit, result }

class CameraScreen extends StatefulWidget {
  final String userPhone;
  const CameraScreen({super.key, required this.userPhone});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  ScanStage _stage = ScanStage.capture;
  File? _imageFile;
  bool _isLoading = false;
  
  // Data Containers
  List<dynamic> _detectedItems = [];
  Map<String, dynamic>? _auditData; 
  Map<String, dynamic>? _finalVerdict; 
  
  // Selection State
  String _selectedSource = "home"; 
  String _primaryItemId = "";

  // ----------------------------------------------------------------------
  // 1. VISION ENGINE (YOLO)
  // ----------------------------------------------------------------------
  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await ImagePicker().pickImage(source: source);
    if (image == null) return;

    setState(() {
      _imageFile = File(image.path);
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.scanMeal));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var res = await http.Response.fromStream(await request.send());

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _detectedItems = data['items'] ?? []; // Safety check
          if (_detectedItems.isNotEmpty) {
            _primaryItemId = _detectedItems[0]['id'].toString(); // Ensure String
            _stage = ScanStage.detection;
          } else {
            _showError("No food detected. Please try again.");
            _stage = ScanStage.capture;
          }
        });
      } else {
        _showError("Server Error: ${res.statusCode}");
      }
    } catch (e) {
      _showError("Vision Error: Check connection.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------------------
  // 2. CONTEXT ENGINE (Audit Question)
  // ----------------------------------------------------------------------
  Future<void> _fetchAuditQuestion(String source) async {
    setState(() {
      _selectedSource = source;
      _isLoading = true;
    });

    try {
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/get_audit_question"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "food_id": _primaryItemId,
          "source": source
        }),
      );

      if (res.statusCode == 200) {
        setState(() {
          _auditData = jsonDecode(res.body);
          _stage = ScanStage.audit;
        });
      } else {
        // Fallback if audit fails
        _submitScan(true); 
      }
    } catch (e) {
      _showError("Audit Error: $e");
      _submitScan(true); // Fallback to submit
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------------------
  // 3. CLINICAL ENGINE (Verdict)
  // ----------------------------------------------------------------------
  Future<void> _submitScan(bool isPositive) async {
    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/submit_scan_result"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": widget.userPhone,
          "food_id": _primaryItemId,
          "source": _selectedSource,
          "is_positive": isPositive,
          // Safely map other items
          "other_items": _detectedItems.map((e) => e['id'].toString()).toList()
        }),
      );

      if (res.statusCode == 200) {
        setState(() {
          _finalVerdict = jsonDecode(res.body)['verdict'];
          _stage = ScanStage.result;
        });
      }
    } catch (e) {
      _showError("Verdict Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _reset() => setState(() {
    _stage = ScanStage.capture;
    _imageFile = null;
    _detectedItems = [];
    _auditData = null;
    _finalVerdict = null;
  });

  void _showError(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)
  );

  // ----------------------------------------------------------------------
  // UI BUILDERS
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text("Vaidya Lens", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AyuTheme.darkGreen,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading 
        ? Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AyuTheme.darkGreen),
              const SizedBox(height: 20),
              Text(_stage == ScanStage.capture ? "Analyzing Food..." : "Consulting Texts...", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: AyuTheme.darkGreen))
            ],
          ))
        : _buildCurrentStage(),
    );
  }

  Widget _buildCurrentStage() {
    switch (_stage) {
      case ScanStage.capture: return _buildCaptureView();
      case ScanStage.detection: return _buildDetectionView();
      case ScanStage.audit: return _buildAuditView();
      case ScanStage.result: return _buildVerdictView();
      default: return _buildCaptureView();
    }
  }

  // --- VIEW 1: CAPTURE ---
  Widget _buildCaptureView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30)]),
            child: const Icon(Icons.center_focus_weak_rounded, size: 80, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          const Text("Scan your meal to analyze\nOjas & Dosha impact", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actionBtn("Camera", Icons.camera_alt_rounded, () => _processImage(ImageSource.camera)),
              const SizedBox(width: 20),
              _actionBtn("Gallery", Icons.photo_library_rounded, () => _processImage(ImageSource.gallery)),
            ],
          )
        ],
      ),
    );
  }

  // --- VIEW 2: DETECTION & CONTEXT (Fixed List & Null Safety) ---
  Widget _buildDetectionView() {
    // We use the full list of detected items now
    return ListView(
      padding: const EdgeInsets.all(25),
      children: [
        if (_imageFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.file(_imageFile!, height: 250, fit: BoxFit.cover),
          ),
        const SizedBox(height: 25),
        const Text("DETECTED ITEMS:", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        
        // Loop through ALL items safely
        ..._detectedItems.map((item) {
          final name = item['name'] ?? "Unknown Food";
          // FIXED: Check both keys to prevent crash
          final dosha = item['dosha_impact'] ?? item['dosha'] ?? "Analyzing..."; 
          
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AyuTheme.darkGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                // Safely show first word of dosha or empty
                Text(dosha.toString().split(' ').first, style: const TextStyle(fontSize: 12, color: Colors.grey)), 
              ],
            ),
          );
        }),

        const Divider(height: 40),
        const Text("Where was this prepared?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        if (_detectedItems.isNotEmpty)
          Text("Focusing on: ${_detectedItems[0]['name']}", style: const TextStyle(fontSize: 12, color: Colors.grey)), 
        
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _contextCard("Home Cooked", Icons.home_rounded, Colors.green, () => _fetchAuditQuestion("home"))),
            const SizedBox(width: 15),
            Expanded(child: _contextCard("Restaurant", Icons.storefront_rounded, Colors.orange, () => _fetchAuditQuestion("restaurant"))),
          ],
        )
      ],
    );
  }

  // --- VIEW 3: CLINICAL AUDIT ---
  Widget _buildAuditView() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.manage_search_rounded, size: 60, color: AyuTheme.darkGreen),
          const SizedBox(height: 30),
          Text(_auditData?['question'] ?? "Verifying quality...", 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4, color: Color(0xFF2D3142)),
          ),
          const SizedBox(height: 50),
          _auditBtn(_auditData?['positive_label'] ?? "Yes", true, Colors.green),
          const SizedBox(height: 15),
          _auditBtn(_auditData?['negative_label'] ?? "No", false, Colors.redAccent),
        ],
      ),
    );
  }

  // --- VIEW 4: FINAL VERDICT (With Full Plate Analysis) ---
  Widget _buildVerdictView() {
    final v = _finalVerdict!;
    final score = v['ojas_update'] ?? 0;
    final isGood = score > 0;
    final warnings = (v['warnings'] as List?) ?? [];
    final plate = (v['plate_analysis'] as List?) ?? []; // The personal breakdown list

    return ListView(
      padding: const EdgeInsets.all(25),
      children: [
        // 1. Ojas Impact Card
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isGood ? [const Color(0xFFE8F5E9), Colors.white] : [const Color(0xFFFFEBEE), Colors.white],
              begin: Alignment.topLeft, end: Alignment.bottomRight
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isGood ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]
          ),
          child: Column(
            children: [
              Text(isGood ? "SATTVIC MEAL" : "TAMASIC MEAL", 
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12, color: isGood ? Colors.green[800] : Colors.red[800])),
              const SizedBox(height: 10),
              Text(score > 0 ? "+$score" : "$score", 
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: isGood ? AyuTheme.darkGreen : Colors.redAccent)),
              const Text("Ojas Impact", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // 2. Personal Body Impact List (NEW)
        const SizedBox(height: 25),
        const Text("Personal Body Impact", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        ...plate.map((p) {
          final isCompat = p['is_compatible'] == true;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isCompat ? Icons.thumb_up_alt_rounded : Icons.warning_rounded,
              color: isCompat ? Colors.green : Colors.orange
            ),
            title: Text(p['name'] ?? "Food", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              isCompat ? "Good for your Dosha" : (p['risk_msg'] ?? "Use in moderation"),
              style: TextStyle(color: isCompat ? Colors.green : Colors.orange[800], fontSize: 12)
            ),
          );
        }),

        // 3. Viruddha Alerts
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withOpacity(0.2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 10), Text("TOXIC COMBINATION", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 10),
                ...warnings.map((w) => Text("• $w", style: const TextStyle(color: Colors.red, height: 1.4))),
              ],
            ),
          )
        ],

        // 4. Details
        const SizedBox(height: 30),
        const Text("Clinical Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _infoRow("Food Quality", v['quality'] ?? "Standard"),
        _infoRow("2-Hour Check", (v['timer_set'] ?? false) ? "Scheduled 🕒" : "Not Required"),
        
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AyuTheme.darkGreen, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          onPressed: _reset,
          child: const Text("SCAN NEXT MEAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  // --- WIDGET HELPERS ---

  Widget _actionBtn(String label, IconData icon, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      child: Container(
        width: 120, height: 120,
        decoration: BoxDecoration(color: AyuTheme.darkGreen, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AyuTheme.darkGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 32), const SizedBox(height: 10), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _contextCard(String title, IconData icon, Color color, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 40, color: color), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _auditBtn(String label, bool val, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, foregroundColor: color, elevation: 0,
        side: BorderSide(color: color.withOpacity(0.3)),
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
      ),
      onPressed: () => _submitScan(val),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Icon(Icons.arrow_forward_ios, size: 16, color: color)]),
    );
  }

  Widget _infoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(val, style: const TextStyle(fontWeight: FontWeight.bold))]),
    );
  }
}