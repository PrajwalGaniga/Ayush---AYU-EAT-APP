import 'package:flutter/material.dart';
import '../theme/ayu_theme.dart';

class DietGuidelinesScreen extends StatelessWidget {
  final String dominant;
  const DietGuidelinesScreen({super.key, required this.dominant});

  @override
  Widget build(BuildContext context) {
    final bool isPitta = dominant == "Pitta";
    final bool isVata = dominant == "Vata";

    return Scaffold(
      appBar: AppBar(title: Text("Pathya-Apathya ($dominant)"), backgroundColor: AyuTheme.darkGreen, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCategory(
            title: "PATHYA (Wholesome - Eat More)", 
            color: Colors.green, 
            foods: isPitta ? ["Ghee", "Appam", "Sweet Fruits"] : (isVata ? ["Warm Soups", "Root Veggies", "Milk"] : ["Ginger", "Honey", "Light Pulses"])
          ),
          const SizedBox(height: 20),
          _buildCategory(
            title: "APATHYA (Unwholesome - Avoid)", 
            color: Colors.red, 
            foods: isPitta ? ["Spicy Chilies", "Vinegar", "Deep Fried"] : (isVata ? ["Raw Salads", "Cold Drinks", "Dry Snacks"] : ["Sweets", "Heavy Dairy", "Fried Dough"])
          ),
        ],
      ),
    );
  }

  Widget _buildCategory({required String title, required Color color, required List<String> foods}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        const Divider(),
        ...foods.map((f) => ListTile(
          leading: Icon(Icons.check_circle_outline, color: color),
          title: Text(f),
        )),
      ],
    );
  }
}

