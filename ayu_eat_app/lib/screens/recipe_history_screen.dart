import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';
import '../theme/ayu_theme.dart';

class RecipeHistoryScreen extends StatelessWidget {
  final String phone;
  const RecipeHistoryScreen({super.key, required this.phone});

  Future<List> _fetchHistory() async {
    try {
      final res = await http.get(Uri.parse("${ApiConfig.baseUrl}/recipe_history/$phone"));
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data'];
      }
    } catch (e) {
      debugPrint("History Fetch Error: $e");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text("Your Healing Log"),
        backgroundColor: AyuTheme.darkGreen,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List>(
        future: _fetchHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AyuTheme.darkGreen));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No recipes saved yet. Scan some ingredients!"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final entry = snapshot.data![index];
              final ingredients = (entry['ingredients'] as List).join(", ");

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    entry['recipe_name'], 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AyuTheme.darkGreen)
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text("Ingredients: $ingredients", style: const TextStyle(fontSize: 12)),
                  ),
                  trailing: TextButton(
                    onPressed: () => _showFullDetails(context, entry['full_recipe']),
                    child: const Text("KNOW MORE"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFullDetails(BuildContext context, Map recipe) {
    // This displays the detailed recipe in a modern bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(25),
          children: [
            Text(recipe['recipe_name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(recipe['ayurvedic_benefit'], style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            const Divider(height: 30),
            const Text("Instructions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            ...(recipe['instructions'] as List).map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text("• $step", style: const TextStyle(height: 1.4)),
            )),
          ],
        ),
      ),
    );
  }
}