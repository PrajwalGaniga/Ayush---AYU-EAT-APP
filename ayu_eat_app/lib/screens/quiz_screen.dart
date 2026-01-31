import 'package:flutter/material.dart';
import '../theme/ayu_theme.dart';

class QuizScreen extends StatefulWidget {
  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Ayurvedic Assessment Questions
  final List<Map<String, dynamic>> _questions = [
    {
      "question": "How would you describe your body frame?",
      "options": ["Thin / Bony", "Medium / Athletic", "Large / Stocky"],
      "dosha": ["Vata", "Pitta", "Kapha"]
    },
    {
      "question": "How is your digestion usually?",
      "options": ["Irregular / Gas", "Intense / Quick", "Slow / Heavy"],
      "dosha": ["Vata", "Pitta", "Kapha"]
    },
    {
      "question": "How do you react to weather?",
      "options": ["Hate Cold", "Hate Heat", "Hate Damp/Humid"],
      "dosha": ["Vata", "Pitta", "Kapha"]
    }
  ];

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      _controller.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      // Logic for results page will go here
      print("Quiz Finished!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AyuTheme.accentSage,
      appBar: AppBar(
        title: Text("Prakriti Assessment", style: TextStyle(color: Colors.white)),
        backgroundColor: AyuTheme.darkGreen,
        elevation: 0,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentPage + 1) / _questions.length,
            backgroundColor: Colors.grey[300],
            color: AyuTheme.lightGreen,
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _questions[index]['question'],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AyuTheme.darkGreen),
                      ),
                      SizedBox(height: 40),
                      ...List.generate(3, (i) => _buildOption(index, i)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(int qIdx, int oIdx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: _nextPage,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AyuTheme.lightGreen.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Text(
            _questions[qIdx]['options'][oIdx],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}