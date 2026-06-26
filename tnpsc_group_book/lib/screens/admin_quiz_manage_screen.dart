import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/question.dart';
import '../services/ai_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class AdminQuizManageScreen extends StatefulWidget {
  const AdminQuizManageScreen({super.key});

  @override
  State<AdminQuizManageScreen> createState() => _AdminQuizManageScreenState();
}

class _AdminQuizManageScreenState extends State<AdminQuizManageScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _quizType = 'daily_quiz'; // 'daily_quiz' or 'mock_quiz'
  bool _isLoading = false;
  List<Question> _questions = [];
  String? _docId;

  @override
  void initState() {
    super.initState();
    _fetchQuiz();
  }

  Future<void> _fetchQuiz() async {
    setState(() {
      _isLoading = true;
      _questions = [];
      _docId = null;
    });

    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String collection = _quizType == 'daily_quiz' ? 'quizzes' : 'mock_tests';
    String typeFilter = _quizType == 'daily_quiz' ? 'daily_quiz' : 'daily_quiz'; // Both use 'daily_quiz' type field in firestore but in different collections

    try {
      final query = await FirebaseFirestore.instance
          .collection(collection)
          .where('date', isEqualTo: dateStr)
          .where('type', isEqualTo: typeFilter)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        _docId = doc.id;
        List<dynamic> qList = doc.get('questions') ?? [];
        setState(() {
          _questions = qList.map((q) => Question.fromMap(q as Map<String, dynamic>)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching quiz: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveQuiz() async {
    if (_docId == null) return;

    setState(() => _isLoading = true);
    String collection = _quizType == 'daily_quiz' ? 'quizzes' : 'mock_tests';

    try {
      await FirebaseFirestore.instance.collection(collection).doc(_docId).update({
        'questions': _questions.map((q) => q.toMap()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quiz updated successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving quiz: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _regenerateQuiz() async {
    setState(() => _isLoading = true);
    bool success = false;
    if (_quizType == 'daily_quiz') {
      success = await AiService.generateAndSaveDailyQuiz(_selectedDate);
    } else {
      success = await AiService.generateAndSaveMockQuiz(_selectedDate);
    }

    if (success) {
      await _fetchQuiz();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI Generation failed. Check logs."), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  void _editQuestion(int index) {
    final q = _questions[index];
    final qController = TextEditingController(text: q.question);
    final optControllers = List.generate(4, (i) => TextEditingController(text: q.options[i]));
    final expController = TextEditingController(text: q.explanation);
    int correctIdx = q.correctOptionIndex;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Edit Question ${index + 1}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Question (English\\nTamil)"),
                ),
                const SizedBox(height: 16),
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: i,
                        groupValue: correctIdx,
                        onChanged: (val) => setDialogState(() => correctIdx = val!),
                      ),
                      Expanded(
                        child: TextField(
                          controller: optControllers[i],
                          decoration: InputDecoration(labelText: "Option ${i + 1} (English / Tamil)"),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: expController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Explanation (English. Tamil.)"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _questions[index] = Question(
                    question: qController.text,
                    options: optControllers.map((c) => c.text).toList(),
                    correctOptionIndex: correctIdx,
                    explanation: expController.text,
                    quizType: q.quizType,
                    subject: q.subject,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Quizzes"),
        actions: [
          if (_questions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_rounded),
              onPressed: _isLoading ? null : _saveQuiz,
              tooltip: "Save Changes",
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            _fetchQuiz();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _quizType,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                        items: const [
                          DropdownMenuItem(value: 'daily_quiz', child: Text("Daily Quiz")),
                          DropdownMenuItem(value: 'mock_quiz', child: Text("Mock Quiz")),
                        ],
                        onChanged: (val) {
                          setState(() => _quizType = val!);
                          _fetchQuiz();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text("No quiz found for this date."),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _regenerateQuiz,
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text("Generate with AI"),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final q = _questions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Question ${index + 1}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, size: 20),
                                        onPressed: () => _editQuestion(index),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(q.question, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const Divider(height: 24),
                                  ...List.generate(q.options.length, (optIdx) {
                                    bool isCorrect = optIdx == q.correctOptionIndex;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCorrect ? Icons.check_circle_rounded : Icons.circle_outlined,
                                            size: 16,
                                            color: isCorrect ? Colors.green : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              q.options[optIdx],
                                              style: TextStyle(
                                                color: isCorrect ? Colors.green : null,
                                                fontWeight: isCorrect ? FontWeight.bold : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const Divider(height: 24),
                                  const Text("Explanation:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    q.explanation,
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
