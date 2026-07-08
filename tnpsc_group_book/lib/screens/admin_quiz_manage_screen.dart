import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/question.dart';
import '../services/ai_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../widgets/bilingual_text.dart';

class AdminQuizManageScreen extends StatefulWidget {
  const AdminQuizManageScreen({super.key});

  @override
  State<AdminQuizManageScreen> createState() => _AdminQuizManageScreenState();
}

class _AdminQuizManageScreenState extends State<AdminQuizManageScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _quizType = 'daily_quiz'; // 'daily_quiz', 'mock_quiz', 'room_quiz'
  String _selectedSubject = 'general_tamil';
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

    try {
      if (_quizType == 'room_quiz') {
        final doc = await FirebaseFirestore.instance
            .collection('room_predefined_quizzes')
            .doc(_selectedSubject)
            .get();

        if (doc.exists) {
          _docId = doc.id;
          List<dynamic> qList = doc.get('questions') ?? [];
          // Display the last 50 questions if the pool is large
          if (qList.length > 50) {
            qList = qList.sublist(qList.length - 50);
          }
          setState(() {
            _questions = qList.map((q) => Question.fromMap(q as Map<String, dynamic>)).toList();
          });
        }
      } else {
        String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        String collection = _quizType == 'daily_quiz' ? 'quizzes' : 'mock_tests';
        String typeFilter = 'daily_quiz';

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
    String collection = _quizType == 'daily_quiz'
        ? 'quizzes'
        : (_quizType == 'mock_quiz' ? 'mock_tests' : 'room_predefined_quizzes');

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
    } else if (_quizType == 'mock_quiz') {
      success = await AiService.generateAndSaveMockQuiz(_selectedDate);
    } else {
      success = await AiService.generateAndSaveRoomPredefinedQuiz(_selectedSubject);
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
    
    // Controllers for new structure
    final qEnController = TextEditingController(text: q.questionEn ?? "");
    final qTaController = TextEditingController(text: q.questionTa ?? "");
    final optEnControllers = List.generate(4, (i) => TextEditingController(text: (q.optionsEn != null && i < q.optionsEn!.length) ? q.optionsEn![i] : ""));
    final optTaControllers = List.generate(4, (i) => TextEditingController(text: (q.optionsTa != null && i < q.optionsTa!.length) ? q.optionsTa![i] : ""));
    final expEnController = TextEditingController(text: q.explanationEn ?? "");
    final expTaController = TextEditingController(text: q.explanationTa ?? "");
    
    // Legacy controllers (for editing existing old format)
    final qLegacyController = TextEditingController(text: q.question);
    final optLegacyControllers = List.generate(4, (i) => TextEditingController(text: q.options[i]));
    final expLegacyController = TextEditingController(text: q.explanation);
    
    int correctIdx = q.correctOptionIndex;
    bool isNewFormat = q.questionEn != null || q.questionTa != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Edit Question ${index + 1}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNewFormat) ...[
                  TextField(controller: qEnController, decoration: const InputDecoration(labelText: "Question (English)")),
                  TextField(controller: qTaController, decoration: const InputDecoration(labelText: "Question (Tamil)")),
                ] else ...[
                  TextField(controller: qLegacyController, maxLines: 2, decoration: const InputDecoration(labelText: "Question (Combined)")),
                ],
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
                        child: Column(
                          children: [
                            if (isNewFormat) ...[
                              TextField(controller: optEnControllers[i], decoration: InputDecoration(labelText: "Option ${i + 1} (English)")),
                              TextField(controller: optTaControllers[i], decoration: InputDecoration(labelText: "Option ${i + 1} (Tamil)")),
                            ] else ...[
                              TextField(controller: optLegacyControllers[i], decoration: InputDecoration(labelText: "Option ${i + 1} (Combined)")),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                if (isNewFormat) ...[
                  TextField(controller: expEnController, decoration: const InputDecoration(labelText: "Explanation (English)")),
                  TextField(controller: expTaController, decoration: const InputDecoration(labelText: "Explanation (Tamil)")),
                ] else ...[
                  TextField(controller: expLegacyController, maxLines: 2, decoration: const InputDecoration(labelText: "Explanation (Combined)")),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (isNewFormat) {
                    _questions[index] = Question(
                      questionEn: qEnController.text,
                      questionTa: qTaController.text,
                      optionsEn: optEnControllers.map((c) => c.text).toList(),
                      optionsTa: optTaControllers.map((c) => c.text).toList(),
                      explanationEn: expEnController.text,
                      explanationTa: expTaController.text,
                      correctOptionIndex: correctIdx,
                      // Derived legacy fields
                      question: "${qEnController.text}\n${qTaController.text}",
                      options: List.generate(4, (i) => "${optEnControllers[i].text} / ${optTaControllers[i].text}"),
                      explanation: "${expEnController.text} ${expTaController.text}",
                      quizType: q.quizType,
                      subject: q.subject,
                    );
                  } else {
                    _questions[index] = Question(
                      question: qLegacyController.text,
                      options: optLegacyControllers.map((c) => c.text).toList(),
                      correctOptionIndex: correctIdx,
                      explanation: expLegacyController.text,
                      quizType: q.quizType,
                      subject: q.subject,
                    );
                  }
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
              icon: const AppIcon(AppIcons.save),
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
                    if (_quizType != 'room_quiz')
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const AppIcon(AppIcons.calendar),
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
                      )
                    else
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSubject,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                          items: const [
                            DropdownMenuItem(value: 'general_tamil', child: Text("General Tamil")),
                            DropdownMenuItem(value: 'general_studies', child: Text("General Studies")),
                            DropdownMenuItem(value: 'aptitude', child: Text("Aptitude")),
                            DropdownMenuItem(value: 'current_affairs', child: Text("Current Affairs")),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedSubject = val!);
                            _fetchQuiz();
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
                          DropdownMenuItem(value: 'room_quiz', child: Text("Room Quiz")),
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
                            const AppIcon(AppIcons.quiz, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text("No quiz found for this date."),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _regenerateQuiz,
                              icon: const AppIcon(AppIcons.ai),
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
                                        style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                      IconButton(
                                        icon: const AppIcon(AppIcons.edit, size: 20),
                                        onPressed: () => _editQuestion(index),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  BilingualText(
                                    en: q.questionEn,
                                    ta: q.questionTa,
                                    legacy: q.question,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  const Divider(height: 24),
                                  ...List.generate(q.options.length, (optIdx) {
                                    bool isCorrect = optIdx == q.correctOptionIndex;
                                    
                                    String? optEn;
                                    String? optTa;
                                    if (q.optionsEn != null && optIdx < q.optionsEn!.length) {
                                      optEn = q.optionsEn![optIdx];
                                      optTa = q.optionsTa![optIdx];
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          AppIcon(
                                            isCorrect ? AppIcons.check : AppIcons.uncheck,
                                            size: 16,
                                            color: isCorrect ? Colors.green : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: BilingualText(
                                              en: optEn,
                                              ta: optTa,
                                              legacy: q.options[optIdx],
                                              fontSize: 14,
                                              color: isCorrect ? Colors.green : null,
                                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const Divider(height: 24),
                                  Text("Explanation:", style: AppTheme.getStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  BilingualText(
                                    en: q.explanationEn,
                                    ta: q.explanationTa,
                                    legacy: q.explanation,
                                    fontSize: 13,
                                    color: Colors.grey,
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
