import 'package:flutter/widgets.dart';
import 'package:tnpsc_group_book/services/ai_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AiService.generateAndSaveDailyQuiz(DateTime.now());
}
