import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/ayu_theme.dart';
import '../api/api_config.dart';

class GrowthSummaryScreen extends StatefulWidget {
  final String userPhone;
  const GrowthSummaryScreen({super.key, required this.userPhone});

  @override
  State<GrowthSummaryScreen> createState() => _GrowthSummaryScreenState();
}

class _GrowthSummaryScreenState extends State<GrowthSummaryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.userProfile(widget.userPhone)));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _history = data['data']['growth_history'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("History Fetch Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Growth Insights"), backgroundColor: AyuTheme.darkGreen, foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ojas Vitality Journey", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Based on your weekly Dinacharya rituals.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                Expanded(child: _history.isEmpty ? const Center(child: Text("No history found yet.")) : _buildLineChart()),
              ],
            ),
          ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: true, topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        lineBarsData: [
          LineChartBarData(
            spots: _history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['score'] as num).toDouble())).toList(),
            isCurved: true,
            color: AyuTheme.darkGreen,
            barWidth: 5,
            belowBarData: BarAreaData(show: true, color: AyuTheme.darkGreen.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}