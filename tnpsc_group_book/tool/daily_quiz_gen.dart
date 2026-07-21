import 'package:flutter/widgets.dart';
import 'package:tnpsc_group_book/services/ai_service.dart';
import 'package:tnpsc_group_book/utils/app_date.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AiService.generateAndSaveDailyQuiz(AppDate.getISTNow());
}
