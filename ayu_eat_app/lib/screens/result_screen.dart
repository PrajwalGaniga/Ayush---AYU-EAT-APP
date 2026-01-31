import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/ayu_theme.dart';
import 'dashboard_screen.dart';
import '../services/auth_service.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, double> doshaScores; // e.g., {"Vata": 40, "Pitta": 30, "Kapha": 30}

  const ResultScreen({super.key, required this.doshaScores});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Your Prakriti Analysis"), backgroundColor: AyuTheme.darkGreen, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text("Your Dominant Dosha", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            
            // RADAR CHART
            SizedBox(
              height: 300,
              child: RadarChart(
                RadarChartData(
                  dataSets: [
                    RadarDataSet(
                      fillColor: AyuTheme.lightGreen.withOpacity(0.4),
                      borderColor: AyuTheme.darkGreen,
                      entryRadius: 3,
                      dataEntries: [
                        RadarEntry(value: doshaScores['Vata']!),
                        RadarEntry(value: doshaScores['Pitta']!),
                        RadarEntry(value: doshaScores['Kapha']!),
                      ],
                    ),
                  ],
                  getTitle: (index, angle) {
                    switch (index) {
                      case 0: return const RadarChartTitle(text: 'VATA');
                      case 1: return const RadarChartTitle(text: 'PITTA');
                      case 2: return const RadarChartTitle(text: 'KAPHA');
                      default: return const RadarChartTitle(text: '');
                    }
                  },
                ),
              ),
            ),
            
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                await AuthService.saveSession("user_id", "User Name", true); // Mark onboarding as DONE
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
              },
              child: const Text("Proceed to Dashboard"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}