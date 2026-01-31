import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';
// Import your new history screen here
import 'recipe_history_screen.dart'; 

class RecipeLabScreen extends StatefulWidget {
  final String userPhone;
  final String dominant;
  const RecipeLabScreen({super.key, required this.userPhone, required this.dominant});

  @override
  State<RecipeLabScreen> createState() => _RecipeLabScreenState();
}

class _RecipeLabScreenState extends State<RecipeLabScreen> {
  final List<String> _selected = [];
  bool _isLoading = false;
  Map<String, dynamic>? _recipe;

  // --- 50+ Ingredient Pantry ---
  final List<Map<String, String>> _items = [
  // --- Grains & Staples ---
  {"name": "Basmati Rice", "icon": "🍚", "impact": "Cooling / Tridoshic"},
  {"name": "Quinoa", "icon": "🌾", "impact": "Protein Rich / Light"},
  {"name": "Oats", "icon": "🥣", "impact": "Heart Healthy / Vata"},
  {"name": "Moong Dal", "icon": "🍲", "impact": "Easy Digestion"},
  {"name": "Whole Wheat", "icon": "🍞", "impact": "Grounding / Kapha"},

  // --- Fats & Dairy ---
  {"name": "Ghee", "icon": "🧈", "impact": "Liquid Gold / Ojas+"},
  {"name": "Coconut Oil", "icon": "🥥", "impact": "Pitta Cooling"},
  {"name": "Sesame Oil", "icon": "🧴", "impact": "Vata Warming"},
  {"name": "A2 Milk", "icon": "🥛", "impact": "Nourishing"},
  {"name": "Yogurt", "icon": "🍦", "impact": "Probiotic / Agni+"},

  // --- Spices (The Medicine) ---
  {"name": "Turmeric", "icon": "🟡", "impact": "Anti-Inflammatory"},
  {"name": "Ginger", "icon": "🫚", "impact": "Universal Medicine"},
  {"name": "Cumin", "icon": "🌱", "impact": "Digestive Support"},
  {"name": "Coriander", "icon": "🌿", "impact": "Cooling Spice"},
  {"name": "Black Pepper", "icon": "🌶️", "impact": "Bio-availability"},
  {"name": "Cardamom", "icon": "🟢", "impact": "Sweet & Cooling"},
  {"name": "Cinnamon", "icon": "🪵", "impact": "Blood Sugar / Kapha"},
  {"name": "Asafoetida", "icon": "🌬️", "impact": "Anti-Bloating"},
  {"name": "Fenugreek", "icon": "🍃", "impact": "Blood Purifier"},
  {"name": "Saffron", "icon": "🌸", "impact": "Vitality / Ojas"},

  // --- Vegetables ---
  {"name": "Spinach", "icon": "🥬", "impact": "Iron Rich"},
  {"name": "Pumpkin", "icon": "🎃", "impact": "Vata Soothing"},
  {"name": "Bitter Gourd", "icon": "🥒", "impact": "Detoxifying"},
  {"name": "Bottle Gourd", "icon": "🎍", "impact": "Hydrating"},
  {"name": "Carrot", "icon": "🥕", "impact": "Beta Carotene"},
  {"name": "Sweet Potato", "icon": "🍠", "impact": "Stable Energy"},
  {"name": "Asparagus", "icon": "🎋", "impact": "Pitta Balancing"},
  {"name": "Beetroot", "icon": "🩸", "impact": "Liver Tonic"},
  {"name": "Drumstick", "icon": "🦯", "impact": "Moringa Power"},
  {"name": "Cucumber", "icon": "🥒", "impact": "Summer Cooling"},

  // --- Fruits ---
  {"name": "Amla", "icon": "🟢", "impact": "Vitamin C King"},
  {"name": "Dates", "icon": "🌴", "impact": "Natural Sweetener"},
  {"name": "Pomegranate", "icon": "🍎", "impact": "Heart & Blood"},
  {"name": "Banana", "icon": "🍌", "impact": "Potassium / Vata"},
  {"name": "Papaya", "icon": "🧡", "impact": "Enzyme Rich"},
  {"name": "Apple", "icon": "🍎", "impact": "Fiber / Kapha"},

  // --- Nuts & Seeds ---
  {"name": "Almonds", "icon": "🥜", "impact": "Brain Health"},
  {"name": "Walnuts", "icon": "🧠", "impact": "Nervous System"},
  {"name": "Flax Seeds", "icon": "🧺", "impact": "Omega-3"},
  {"name": "Chia Seeds", "icon": "🍮", "impact": "Hydration"},
  {"name": "Pumpkin Seeds", "icon": "🎃", "impact": "Zinc / Immunity"},

  // --- Herbs & Others ---
  {"name": "Tulsi", "icon": "🍃", "impact": "Holy Basil / Stress"},
  {"name": "Neem", "icon": "🌳", "impact": "Blood Cleanse"},
  {"name": "Honey", "icon": "🍯", "impact": "Yogavahi / Kapha-"},
  {"name": "Jaggery", "icon": "🟫", "impact": "Iron / Vata-"},
  {"name": "Rock Salt", "icon": "🧂", "impact": "Mineral Rich"},
  {"name": "Lemon", "icon": "🍋", "impact": "Vitamin C / Agni"},
  {"name": "Curry Leaves", "icon": "🌿", "impact": "Hair & Digestion"},
  {"name": "Garlic", "icon": "🧄", "impact": "Natural Antibiotic"},
  {"name": "Mint", "icon": "🍃", "impact": "Digestive Cooling"},
];

  Future<void> _fetchRecipe() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/generate_recipe/${widget.userPhone}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(_selected),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _recipe = body['data'];
          _isLoading = false;
        });
      }
    } on TimeoutException {
      _handleError("Chef is taking too long. Please retry.");
    } catch (e) {
      _handleError("Connection Error. Try again.");
    }
  }

  void _handleError(String msg) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vaidya AI Lab", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AyuTheme.darkGreen,
        foregroundColor: Colors.white,
        actions: [
          // SMART ADDITION: History Access
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: "Recipe History",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RecipeHistoryScreen(phone: widget.userPhone)),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading 
          ? _buildLoading() 
          : (_recipe == null ? _buildSelection() : _buildResult()),
    );
  }

  Widget _buildLoading() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AyuTheme.darkGreen),
        const SizedBox(height: 20),
        Text("Vaidya is analyzing your ${widget.dominant} prakriti...", 
          style: const TextStyle(fontStyle: FontStyle.italic, color: AyuTheme.darkGreen)),
      ],
    ),
  );

  Widget _buildSelection() {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              childAspectRatio: 0.9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final name = _items[i]['name']!;
              final isSel = _selected.contains(name);
              return GestureDetector(
                onTap: () => setState(() => isSel ? _selected.remove(name) : _selected.add(name)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSel ? AyuTheme.darkGreen : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                    border: Border.all(color: isSel ? AyuTheme.darkGreen : Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_items[i]['icon']!, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 4),
                      Text(name, textAlign: TextAlign.center, style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : Colors.black87
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AyuTheme.darkGreen,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _selected.length >= 2 ? _fetchRecipe : null,
            child: const Text("GENERATE MEDICINAL RECIPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final name = _recipe?['recipe_name'] ?? "Ayurvedic Meal";
    final benefit = _recipe?['ayurvedic_benefit'] ?? "Balances your Agni";
    final steps = (_recipe?['instructions'] as List?)?.cast<String>() ?? ["Preparation pending..."];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AyuTheme.darkGreen))),
            const Icon(Icons.verified, color: Colors.blue, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AyuTheme.lightGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(benefit, style: const TextStyle(fontStyle: FontStyle.italic, color: AyuTheme.darkGreen, height: 1.4)),
        ),
        const Divider(height: 40),
        const Text("Steps for Preparation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ...steps.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 12, backgroundColor: AyuTheme.darkGreen, child: Text("${e.key + 1}", style: const TextStyle(fontSize: 12, color: Colors.white))),
              const SizedBox(width: 15),
              Expanded(child: Text(e.value, style: const TextStyle(fontSize: 15, height: 1.5))),
            ],
          ),
        )),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000), minimumSize: const Size(double.infinity, 50)),
          onPressed: () => launchUrl(Uri.parse("https://youtube.com/results?search_query=${_recipe?['youtube_query']}")),
          icon: const Icon(Icons.play_circle_fill, color: Colors.white),
          label: const Text("WATCH VIDEO TUTORIAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: () => setState(() => _recipe = null), child: const Center(child: Text("Start New Scan", style: TextStyle(color: AyuTheme.darkGreen)))),
      ],
    );
  }
}