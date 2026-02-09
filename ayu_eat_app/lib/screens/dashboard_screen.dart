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
import '../services/local_storage.dart';
import 'recipe_lab_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userPhone;
  const DashboardScreen({super.key, required this.userPhone});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  // --- STATE VARIABLES (Preserved) ---
  Map<String, dynamic>? userData;
  Map<String, dynamic>? weeklySummary;
  bool _isLoading = true;
  String _lang = "en"; // Language Toggle State

  // --- ANIMATION CONTROLLERS ---
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize animations FIRST to prevent LateInitializationError
    _setupAnimations();
    // Then fetch data
    _fetchFullData();
    _checkBioFeedback();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // dashboard_screen.dart

  // --- NEW: BIO-FEEDBACK CHECKER ---
  Future<void> _checkBioFeedback() async {
    try {
      final res = await http.get(Uri.parse("${ApiConfig.baseUrl}/post_meal_status/${widget.userPhone}"));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        // Only show if status is 'due'
        if (data['status'] == 'due') {
          _showFeedbackModal(data);
        }
      }
    } catch (e) {
      debugPrint("Feedback Check Failed: $e");
    }
  }

  void _showFeedbackModal(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_filled_rounded, size: 50, color: AyuTheme.darkGreen),
            const SizedBox(height: 15),
            Text("2 Hours Later...", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Digestion Check: ${data['meal_name']}", 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 20),
            
            // Dynamic Questions List
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: (data['questions'] as List).map<Widget>((q) => 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(children: [
                      const Icon(Icons.help_outline, size: 18, color: Colors.grey), 
                      const SizedBox(width: 10), 
                      Expanded(child: Text(q, style: const TextStyle(fontSize: 15)))
                    ]),
                  )
                ).toList(),
              ),
            ),
            
            const SizedBox(height: 25),
            const Text("How does your body feel?", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(child: _feedbackBtn("Heavy / Bad", Colors.red[50]!, Colors.red, "Bad")),
                const SizedBox(width: 15),
                Expanded(child: _feedbackBtn("Light / Energetic", Colors.green[50]!, Colors.green, "Good")),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _feedbackBtn(String label, Color bg, Color textCol, String value) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: textCol,
        padding: const EdgeInsets.symmetric(vertical: 15),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
      ),
      onPressed: () async {
        Navigator.pop(context); // Close Modal
        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/submit_feedback/${widget.userPhone}"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"feeling": value})
        );
        _fetchFullData(); // Refresh Dashboard with new Ojas
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ojas Updated based on feedback!"), backgroundColor: AyuTheme.darkGreen)
        );
      },
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  // --- LOGIC: DATA FETCHING (Preserved) ---
  Future<void> _fetchFullData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.userProfile(widget.userPhone))).timeout(const Duration(seconds: 5)),
        http.get(Uri.parse("${ApiConfig.baseUrl}/weekly_summary/${widget.userPhone}")).timeout(const Duration(seconds: 5)),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        final profile = jsonDecode(results[0].body);
        final summary = jsonDecode(results[1].body);

        await LocalCache.save("profile_${widget.userPhone}", profile);
        await LocalCache.save("summary_${widget.userPhone}", summary);

        if (!mounted) return;
        setState(() {
          userData = profile['data'];
          weeklySummary = summary;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("Offline mode: Loading cached dashboard data.");
    }

    final cachedProfile = await LocalCache.get("profile_${widget.userPhone}");
    final cachedSummary = await LocalCache.get("summary_${widget.userPhone}");

    if (mounted) {
      setState(() {
        if (cachedProfile != null) userData = cachedProfile['data'];
        if (cachedSummary != null) weeklySummary = cachedSummary;
        _isLoading = false;
      });
    }
  }

  // --- LOGIC: ASSETS & COLORS (Preserved) ---
  String _getAvatarAsset(String gender, int score) {
    bool isMale = gender.toLowerCase() == 'male';
    String path = 'assets/images/';
    if (score < 50) {
      return isMale ? '${path}unhealthy_male.png' : '${path}unhealthy_female.png';
    } else {
      return isMale ? '${path}healthy_male.png' : '${path}healthy_female.png';
    }
  }

  Color _getStatusColor(int score) {
    if (score < 40) return AyuTheme.warningRed;
    if (score < 60) return Colors.orange;
    return const Color(0xFF4CAF50);
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAF8),
        body: Center(child: CircularProgressIndicator(color: AyuTheme.darkGreen)),
      );
    }

    // Data Extraction
    final name = userData?['fullname'] ?? "Seeker";
    final prakriti = userData?['prakriti'] ?? {};
    final v = (prakriti['vata'] ?? 33.3).toDouble();
    final p = (prakriti['pitta'] ?? 33.3).toDouble();
    final k = (prakriti['kapha'] ?? 33.3).toDouble();
    final dominant = prakriti['dominant'] ?? "Balanced";
    final ojasScore = userData?['ojas_score'] ?? 50;
    final gender = userData?['gender'] ?? 'male';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8), // Premium Off-White
      extendBody: true,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Glassmorphism Header
          _buildPersistentHeader(name),

          // 2. Immersive Hero Section
          SliverToBoxAdapter(
            child: _buildImmersiveHero(gender, ojasScore, dominant),
          ),

          // 3. Main Content Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 25),

                // Weekly Pulse
                if (weeklySummary != null) ...[
                  _buildSectionHeader(
                    _lang == "en" ? "Weekly Pulse" : "ವಾರದ ವರದಿ",
                    Icons.show_chart_rounded
                  ),
                  const SizedBox(height: 16),
                  _buildWeeklyMetricsCard(weeklySummary!),
                  const SizedBox(height: 32),
                ],

                // Wellness Hub Grid
                _buildSectionHeader(
                  _lang == "en" ? "Wellness Hub" : "ಆರೋಗ್ಯ ಕೇಂದ್ರ",
                  Icons.grid_view_rounded
                ),
                const SizedBox(height: 16),
                _buildWellnessGrid(dominant),
                const SizedBox(height: 32),

                // Dosha Balance
                _buildSectionHeader(
                  _lang == "en" ? "Dosha Balance" : "ದೋಷ ಸಮತೋಲನ",
                  Icons.incomplete_circle_rounded
                ),
                const SizedBox(height: 16),
                _buildDoshaRadar(v, p, k),
                const SizedBox(height: 32),

                // Wisdom Card
                _buildWisdomCard(dominant),
                const SizedBox(height: 120), // Space for FAB
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildPulsingFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --------------------------------------------------------------------------
  // 1️⃣ PERSISTENT HEADER (Glassmorphic SliverAppBar)
  // --------------------------------------------------------------------------
  Widget _buildPersistentHeader(String name) {
    final firstName = name.split(" ")[0];

    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFFF8FAF8).withOpacity(0.85),
      toolbarHeight: 70,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      // REPLACE your current Title Row with this:
title: Row(
  children: [
    GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userPhone: widget.userPhone))),
      child: const CircleAvatar(
        radius: 18,
        backgroundColor: AyuTheme.accentSage,
        child: Icon(Icons.person, color: AyuTheme.darkGreen, size: 20),
      ),
    ),
    const SizedBox(width: 12),
    // FIX: Wrap Text in Flexible to prevent overflow
    Flexible( 
      child: Text(
        "Namaste, ${name.split(' ')[0]}", 
        style: const TextStyle(color: Color(0xFF2D3142), fontSize: 18, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis, // Adds "..." if too long
      ),
    ),
  ],
),
      actions: [
        // Language Toggle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 18),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              _buildLangOption("EN", _lang == "en"),
              _buildLangOption("KN", _lang == "kn"),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: Colors.grey[700]),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          surfaceTintColor: Colors.white,
          onSelected: (value) {
            if (value == 'profile') Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userPhone: widget.userPhone)));
            if (value == 'logout') AuthService.logout().then((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen())));
            if (value == 'refresh') _fetchFullData();
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
             PopupMenuItem<String>(
              value: 'profile',
              child: ListTile(
                leading: const Icon(Icons.person_outline, size: 20),
                title: const Text('My Profile'),
                contentPadding: EdgeInsets.zero,
                titleTextStyle: TextStyle(fontSize: 14, color: Colors.grey[800]),
              )
            ),
             PopupMenuItem<String>(
              value: 'refresh',
              child: ListTile(
                leading: const Icon(Icons.refresh, size: 20),
                title: const Text('Refresh Data'),
                contentPadding: EdgeInsets.zero,
                titleTextStyle: TextStyle(fontSize: 14, color: Colors.grey[800]),
              )
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red, size: 20),
                title: Text('Logout'),
                contentPadding: EdgeInsets.zero,
                titleTextStyle: TextStyle(fontSize: 14, color: Colors.red),
              )
            ),
          ],
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildLangOption(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _lang = text.toLowerCase()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AyuTheme.darkGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2️⃣ IMMERSIVE HERO (Refined Visuals)
  // --------------------------------------------------------------------------
  Widget _buildImmersiveHero(String gender, int score, String dominant) {
    final bool isHighScore = score >= 50;
    
    return Container(
      height: 360,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHighScore
              ? [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)] // Healing Green
              : [const Color(0xFFF5F5F5), const Color(0xFFE0E0E0)], // Neutral Grey
        ),
        boxShadow: [
          BoxShadow(
            color: AyuTheme.darkGreen.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient Background Icon
          Positioned(
            top: -40,
            right: -40,
            child: Icon(Icons.spa_rounded, size: 240, color: Colors.white.withOpacity(0.4)),
          ),

          // Vitality Score (Top Left)
          Positioned(
            top: 28,
            left: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monitor_heart_outlined, size: 14, color: AyuTheme.darkGreen.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(
                        "VITALITY INDEX",
                        style: TextStyle(
                          color: AyuTheme.darkGreen.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "$score",
                      style: TextStyle(
                        color: AyuTheme.darkGreen,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -1.0
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 4),
                      child: Text(
                        "/100",
                        style: TextStyle(
                          color: AyuTheme.darkGreen.withOpacity(0.5),
                          fontSize: 18,
                          fontWeight: FontWeight.w700
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(score).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        score > 50 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 16,
                        color: _getStatusColor(score),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        score > 50 ? "Doing Well" : "Needs Care",
                        style: TextStyle(
                          color: _getStatusColor(score),
                          fontWeight: FontWeight.bold,
                          fontSize: 12
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Avatar Image (Centered Bottom)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Hero(
                tag: 'userAvatar',
                child: Image.asset(
                  _getAvatarAsset(gender, score),
                  height: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.person, size: 120, color: Colors.black12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 3️⃣ WEEKLY METRICS (Clean Card)
  // --------------------------------------------------------------------------
  Widget _buildWeeklyMetricsCard(Map<String, dynamic> summary) {
    final completion = (summary['task_completion'] as num).toDouble();
    final avgOjas = (summary['avg_ojas'] as num).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCircularIndicator(
              "Rituals",
              completion / 100,
              const Color(0xFF5C6BC0), // Soft Indigo
              Icons.check_circle_outline_rounded
            ),
            VerticalDivider(color: Colors.grey[100], thickness: 1.5, width: 30),
            _buildCircularIndicator(
              "Avg Ojas",
              avgOjas / 100,
              const Color(0xFFFFA726), // Soft Orange
              Icons.bolt_rounded
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularIndicator(String label, double value, Color color, IconData icon) {
    return Column(
      children: [
        SizedBox(
          height: 60, width: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                backgroundColor: color.withOpacity(0.08),
                color: color,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${(value * 100).toInt()}%",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF2D3142)),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 4️⃣ WELLNESS GRID (Refined)
  // --------------------------------------------------------------------------
  Widget _buildWellnessGrid(String dominant) {
    final actions = [
      {
        "title": _lang == "en" ? "Recipe Lab" : "ರೆಸಿಪಿ ಲ್ಯಾಬ್",
        "sub": _lang == "en" ? "Heal with Food" : "ಔಷಧೀಯ ಆಹಾರ",
        "icon": Icons.restaurant_menu_rounded,
        "color": const Color(0xFFFFA726),
        "bg": const Color(0xFFFFF3E0),
        "tap": () => Navigator.push(context, MaterialPageRoute(builder: (c) => RecipeLabScreen(userPhone: widget.userPhone, dominant: dominant)))
      },
      {
        "title": _lang == "en" ? "Daily Check" : "ದಿನಚರ್ಯ",
        "sub": _lang == "en" ? "Track Habits" : "ಅಭ್ಯಾಸಗಳು",
        "icon": Icons.task_alt_rounded,
        "color": const Color(0xFF66BB6A),
        "bg": const Color(0xFFE8F5E9),
        "tap": () => Navigator.push(context, MaterialPageRoute(builder: (c) => WeeklyChecklistScreen(userPhone: widget.userPhone, prakriti: userData?['prakriti'])))
      },
      {
        "title": _lang == "en" ? "Vaidya Chat" : "ವೈದ್ಯ ಚಾಟ್",
        "sub": _lang == "en" ? "AI Diagnosis" : "ಆರೋಗ್ಯ ಸಲಹೆ",
        "icon": Icons.psychology_rounded,
        "color": const Color(0xFF42A5F5),
        "bg": const Color(0xFFE3F2FD),
        "tap": () => Navigator.push(context, MaterialPageRoute(builder: (c) => AyushChatScreen(userPhone: widget.userPhone)))
      },
      {
        "title": _lang == "en" ? "Progress" : "ಪ್ರಗತಿ",
        "sub": _lang == "en" ? "Growth Chart" : "ವರದಿ",
        "icon": Icons.bar_chart_rounded,
        "color": const Color(0xFFAB47BC),
        "bg": const Color(0xFFF3E5F5),
        "tap": () => Navigator.push(context, MaterialPageRoute(builder: (c) => GrowthSummaryScreen(userPhone: widget.userPhone)))
      },
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.15,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final item = actions[index];
        return _buildActionCard(
          item['title'] as String,
          item['sub'] as String,
          item['icon'] as IconData,
          item['color'] as Color,
          item['bg'] as Color,
          item['tap'] as VoidCallback,
        );
      },
    );
  }

  Widget _buildActionCard(String title, String sub, IconData icon, Color color, Color bg, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: bg,
        highlightColor: bg.withOpacity(0.5),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2)
              )
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF2D3142)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5️⃣ DOSHA & WISDOM
  // --------------------------------------------------------------------------
  Widget _buildDoshaRadar(double v, double p, double k) => Container(
    height: 340,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.grey.withOpacity(0.08)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 4))
      ],
    ),
    child: Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: RadarChart(RadarChartData(
            radarTouchData: RadarTouchData(enabled: false),
            dataSets: [
              RadarDataSet(
                fillColor: AyuTheme.lightGreen.withOpacity(0.2),
                borderColor: AyuTheme.darkGreen,
                borderWidth: 2,
                entryRadius: 3.5,
                dataEntries: [RadarEntry(value: v), RadarEntry(value: p), RadarEntry(value: k)]
              )
            ],
            radarBackgroundColor: Colors.transparent,
            borderData: FlBorderData(show: false),
            radarBorderData: const BorderSide(color: Colors.transparent),
            titlePositionPercentageOffset: 0.2,
            titleTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AyuTheme.darkGreen),
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
            gridBorderData: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
          )),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem("Vata", v, Colors.blue),
              const SizedBox(width: 24),
              _legendItem("Pitta", p, Colors.red),
              const SizedBox(width: 24),
              _legendItem("Kapha", k, Colors.green),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _legendItem(String label, double val, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          "$label ${(val).toInt()}%",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildWisdomCard(String dominant) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF1F8E9), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AyuTheme.darkGreen.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: AyuTheme.darkGreen.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.light_mode_rounded, color: Colors.orange, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lang == "en" ? "DAILY WISDOM" : "ದಿನದ ಜ್ಞಾನ",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _lang == "en"
                    ? "Since you are $dominant, eat warm, cooked meals today."
                    : "$dominant ಪ್ರಕೃತಿಯವರು, ಇಂದು ಬೆಚ್ಚಗಿನ ಊಟ ಮಾಡಿ.",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3142), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 6️⃣ PULSING FAB
  // --------------------------------------------------------------------------
  Widget _buildPulsingFAB() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: AyuTheme.darkGreen.withOpacity(0.3),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: AyuTheme.darkGreen,
          elevation: 0,
          highlightElevation: 0,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CameraScreen(userPhone: widget.userPhone))),
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
          label: Text(
            _lang == "en" ? "SCAN MEAL" : "ಊಟ ಸ್ಕ್ಯಾನ್",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.5
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Section Headers
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AyuTheme.darkGreen),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
        ),
      ],
    );
  }
}