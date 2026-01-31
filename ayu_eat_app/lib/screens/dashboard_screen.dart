import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // For glassmorphism
import 'package:fl_chart/fl_chart.dart';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'camera_screen.dart';
import 'weekly_checklist_screen.dart';
import 'chat_screen.dart';
import 'growth_summary_screen.dart';
import 'recipe_lab_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userPhone;
  const DashboardScreen({super.key, required this.userPhone});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? weeklySummary;
  bool _isLoading = true;
  String _lang = "en"; // Language Toggle State

  @override
  void initState() {
    super.initState();
    _fetchFullData();
  }

  // --- LOGIC: DATA FETCHING ---
  Future<void> _fetchFullData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.userProfile(widget.userPhone))).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse("${ApiConfig.baseUrl}/weekly_summary/${widget.userPhone}")).timeout(const Duration(seconds: 10)),
      ]);

      if (!mounted) return;

      setState(() {
        if (results[0].statusCode == 200) {
          userData = jsonDecode(results[0].body)['data'];
        }
        if (results[1].statusCode == 200) {
          weeklySummary = jsonDecode(results[1].body);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC: AVATAR SELECTION ---
  // Returns the correct asset path based on gender and Ojas score
  String _getAvatarAsset(String gender, int score) {
    bool isMale = gender.toLowerCase() == 'male';
    String path = 'assets/images/'; // Ensure this matches your pubspec.yaml path
    if (score < 50) {
      return isMale ? '${path}unhealthy_male.png' : '${path}unhealthy_female.png';
    } else {
      return isMale ? '${path}healthy_male.png' : '${path}healthy_female.png';
    }
  }

  // --- LOGIC: COLOR CODING ---
  Color _getStatusColor(int score) {
    if (score < 40) return AyuTheme.warningRed;
    if (score < 60) return Colors.orange;
    return const Color(0xFF4CAF50); // Vibrant Green
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7F4),
        body: Center(child: CircularProgressIndicator(color: AyuTheme.darkGreen)),
      );
    }

    // Extract Data safely
    final name = userData?['fullname'] ?? "Seeker";
    final prakriti = userData?['prakriti'] ?? {};
    final v = (prakriti['vata'] ?? 33.3).toDouble();
    final p = (prakriti['pitta'] ?? 33.3).toDouble();
    final k = (prakriti['kapha'] ?? 33.3).toDouble();
    final dominant = prakriti['dominant'] ?? "Balanced";
    final ojasScore = userData?['ojas_score'] ?? 50;
    final gender = userData?['gender'] ?? 'male';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9), // Soft Sage/White Background
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. SNAPCHAT-STYLE FULL HEADER
          _buildImmersiveHeader(gender, ojasScore),

          // 2. SCROLLABLE CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 25),
                  
                  // WELCOME & LANG TOGGLE
                  _buildWelcomeRow(name),
                  const SizedBox(height: 20),

                  // INSIGHT BANNER (Dynamic)
                  _buildInsightBanner(dominant, ojasScore),
                  const SizedBox(height: 25),

                  // WEEKLY METRICS (Horizontal Card)
                  if (weeklySummary != null) _buildHorizontalScorecard(weeklySummary!),
                  const SizedBox(height: 30),

                  // WELLNESS GRID (Action Cards)
                  _buildSectionTitle(_lang == "en" ? "Wellness Hub" : "ಆರೋಗ್ಯ ಕೇಂದ್ರ"),
                  _buildWellnessGrid(dominant),

                  const SizedBox(height: 30),
                  
                  // DOSHA RADAR
                  _buildSectionTitle(_lang == "en" ? "Dosha Balance" : "ದೋಷ ಸಮತೋಲನ"),
                  _buildDoshaRadar(v, p, k),

                  const SizedBox(height: 25),
                  
                  // WISDOM CARD
                  _buildWisdomCard(dominant),
                  
                  const SizedBox(height: 100), // Bottom padding for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AyuTheme.darkGreen,
        elevation: 4,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CameraScreen(userPhone: widget.userPhone))),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: Text(
          _lang == "en" ? "SCAN MEAL" : "ಊಟ ಸ್ಕ್ಯಾನ್ ಮಾಡಿ", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // UI COMPONENTS (REFACTORED)
  // --------------------------------------------------------------------------

  // 1️⃣ HEADER: Full Screen Immersive Avatar
  Widget _buildImmersiveHeader(String gender, int score) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.42, // ~42% Screen Height
      pinned: true,
      stretch: true,
      backgroundColor: AyuTheme.darkGreen,
      elevation: 0,
      leading: Container(), // Hide back button
      actions: [
         // Manual Refresh
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _fetchFullData,
        ),
        // Logout
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () => AuthService.logout().then((_) => 
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen()))
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // A. Gradient Background (The "Environment")
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: score >= 50 
                    ? [const Color(0xFFAED581), AyuTheme.darkGreen] // Healthy: Vibrant Light to Dark Green
                    : [const Color(0xFFB0BEC5), const Color(0xFF455A64)], // Unhealthy: Muted Grey/Blue
                ),
              ),
            ),

            // B. The Avatar (Full Scale, Bottom Aligned)
            Positioned(
              bottom: 0,
              // Height logic ensures the character fills the space without being cut off weirdly
              height: MediaQuery.of(context).size.height * 0.38, 
              child: Hero(
                tag: 'userAvatar',
                child: Image.asset(
                  _getAvatarAsset(gender, score),
                  fit: BoxFit.fitHeight, 
                  errorBuilder: (c, e, s) => const Icon(Icons.person, size: 150, color: Colors.white24),
                ),
              ),
            ),

            // C. Glassmorphism Ojas Score Pill
            Positioned(
              top: MediaQuery.of(context).padding.top + 60, // Below AppBar actions
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: _getStatusColor(score), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          _lang == "en" ? "Ojas: $score%" : "ಓಜಸ್: $score%",
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2️⃣ WELCOME & LANGUAGE TOGGLE
  Widget _buildWelcomeRow(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lang == "en" ? "Namaste," : "ನಮಸ್ತೆ,", 
              style: TextStyle(fontSize: 15, color: Colors.grey[600], letterSpacing: 0.5)
            ),
            const SizedBox(height: 4),
            Text(
              name, 
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AyuTheme.darkGreen)
            ),
          ],
        ),
        // Modern Toggle Button
        GestureDetector(
          onTap: () => setState(() => _lang = _lang == "en" ? "kn" : "en"),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AyuTheme.accentSage,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AyuTheme.darkGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.translate, size: 16, color: AyuTheme.darkGreen),
                const SizedBox(width: 6),
                Text(
                  _lang == "en" ? "ಕನ್ನಡ" : "ENG", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AyuTheme.darkGreen)
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3️⃣ INSIGHT BANNER (Dynamic Context)
  Widget _buildInsightBanner(String dominant, int score) {
    bool isLow = score < 50;
    String textEn = isLow 
      ? "Your vitality is low. Focus on warm meals and deep rest today." 
      : "Your $dominant energy is vibrant! Maintain it with grounding rituals.";
    String textKn = isLow
      ? "ನಿಮ್ಮ ಶಕ್ತಿ ಕಡಿಮೆಯಾಗಿದೆ. ಇಂದು ಬಿಸಿ ಊಟ ಮತ್ತು ವಿಶ್ರಾಂತಿಗೆ ಗಮನ ಕೊಡಿ."
      : "ನಿಮ್ಮ $dominant ಶಕ್ತಿ ಉತ್ತಮವಾಗಿದೆ! ಇದನ್ನು ಯೋಗದೊಂದಿಗೆ ಕಾಪಾಡಿಕೊಳ್ಳಿ.";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: isLow ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ],
        border: Border.all(color: isLow ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isLow ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLow ? Icons.battery_alert : Icons.battery_full, 
              color: isLow ? AyuTheme.warningRed : Colors.green,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              _lang == "en" ? textEn : textKn,
              style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // 4️⃣ WEEKLY METRICS (Horizontal Scorecard)
  Widget _buildHorizontalScorecard(Map<String, dynamic> summary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _metricItem(
              _lang == "en" ? "Daily Rituals" : "ದಿನಚರ್ಯ", 
              summary['task_completion'] / 100, 
              Colors.blueAccent
            ),
            const VerticalDivider(width: 30, indent: 10, endIndent: 10),
            _metricItem(
              _lang == "en" ? "Weekly Avg" : "ವಾರದ ಸರಾಸರಿ", 
              summary['avg_ojas'] / 100, 
              Colors.orangeAccent
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String title, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 60, width: 60,
            child: CircularProgressIndicator(
              value: value,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
            ),
          ),
          const SizedBox(height: 10),
          Text("${(value * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // 5️⃣ WELLNESS GRID (Premium Action Cards)
  Widget _buildWellnessGrid(String dominant) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.1, // Taller cards for better visual balance
      children: [
        _actionCard(
          _lang == "en" ? "Recipe Lab" : "ರೆಸಿಪಿ ಲ್ಯಾಬ್", 
          _lang == "en" ? "Healing Meals" : "ಔಷಧೀಯ ಆಹಾರ",
          Icons.restaurant_menu_rounded, 
          Colors.orange, 
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => RecipeLabScreen(userPhone: widget.userPhone, dominant: dominant)))
        ),
        _actionCard(
          _lang == "en" ? "Daily Check" : "ದಿನಚರ್ಯ", 
          _lang == "en" ? "Track Habits" : "ಅಭ್ಯಾಸಗಳು",
          Icons.check_circle_outline_rounded, 
          AyuTheme.darkGreen, 
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => WeeklyChecklistScreen(userPhone: widget.userPhone, prakriti: userData?['prakriti'])))
        ),
        _actionCard(
          _lang == "en" ? "Vaidya Chat" : "ವೈದ್ಯ ಚಾಟ್", 
          _lang == "en" ? "AI Diagnosis" : "ಆರೋಗ್ಯ ಸಲಹೆ",
          Icons.psychology, 
          Colors.blueAccent, 
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => AyushChatScreen(userPhone: widget.userPhone)))
        ),
        _actionCard(
          _lang == "en" ? "My Progress" : "ನನ್ನ ಪ್ರಗತಿ", 
          _lang == "en" ? "Growth Chart" : "ಬೆಳವಣಿಗೆ ವರದಿ",
          Icons.trending_up_rounded, 
          Colors.purple, 
          () => Navigator.push(context, MaterialPageRoute(builder: (c) => GrowthSummaryScreen(userPhone: widget.userPhone)))
        ),
      ],
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // 6️⃣ DOSHA RADAR (Polished)
  Widget _buildDoshaRadar(double v, double p, double k) => Container(
    height: 300,
    decoration: BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4))],
    ),
    child: Column(
      children: [
        const SizedBox(height: 20),
        Expanded(
          child: RadarChart(RadarChartData(
            radarTouchData: RadarTouchData(enabled: false),
            dataSets: [
              RadarDataSet(
                fillColor: AyuTheme.lightGreen.withOpacity(0.2), 
                borderColor: AyuTheme.darkGreen, 
                borderWidth: 2, 
                entryRadius: 3,
                dataEntries: [RadarEntry(value: v), RadarEntry(value: p), RadarEntry(value: k)]
              )
            ],
            radarBackgroundColor: Colors.transparent,
            borderData: FlBorderData(show: false),
            radarBorderData: const BorderSide(color: Colors.transparent),
            titlePositionPercentageOffset: 0.2,
            titleTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AyuTheme.darkGreen),
            getTitle: (index, _) {
              switch (index) {
                case 0: return const RadarChartTitle(text: 'VATA');
                case 1: return const RadarChartTitle(text: 'PITTA');
                case 2: return const RadarChartTitle(text: 'KAPHA');
                default: return const RadarChartTitle(text: '');
              }
            },
            tickCount: 1,
            ticksTextStyle: const TextStyle(color: Colors.transparent),
            gridBorderData: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
          )),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );

  // 7️⃣ WISDOM CARD (Emotional Design)
  Widget _buildWisdomCard(String dominant) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AyuTheme.accentSage, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AyuTheme.darkGreen.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.self_improvement, color: AyuTheme.darkGreen.withOpacity(0.6), size: 32),
          const SizedBox(height: 12),
          Text(
            _lang == "en" ? "Ayurvedic Wisdom" : "ಆಯುರ್ವೇದ ಜ್ಞಾನ", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            _lang == "en" 
              ? "Since you are $dominant dominant, prioritize warm, cooked meals and avoid dry, cold snacks to maintain balance." 
              : "$dominant ಪ್ರಕೃತಿಯವರು, ಸಮತೋಲನವನ್ನು ಕಾಪಾಡಿಕೊಳ್ಳಲು ಬೆಚ್ಚಗಿನ, ಬೇಯಿಸಿದ ಊಟಕ್ಕೆ ಆದ್ಯತೆ ನೀಡಿ ಮತ್ತು ಒಣ, ತಂಪು ತಿಂಡಿಗಳನ್ನು ತಪ್ಪಿಸಿ.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF37474F), fontSize: 14, height: 1.5),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 15), 
      child: Text(
        title, 
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2E3D30))
      )
    );
  }
}