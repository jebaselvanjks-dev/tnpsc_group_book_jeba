import '../models/question.dart';

class ShareUtils {
  static String generateTelegramPollText(Question q) {
    final String qEn = q.questionEn ?? q.question;
    final String qTa = q.questionTa ?? "";
    
    String text = "📊 *TNPSC Daily Challenge*\n\n";
    text += "*$qEn*\n";
    if (qTa.isNotEmpty) {
      text += "*$qTa*\n";
    }
    text += "\n";

    final options = q.displayOptions;
    final List<String> numberEmojis = ["1️⃣", "2️⃣", "3️⃣", "4️⃣"];
    
    for (int i = 0; i < options.length; i++) {
      String optEn = "";
      String optTa = "";

      if (q.optionsEn != null && i < q.optionsEn!.length) optEn = q.optionsEn![i];
      if (q.optionsTa != null && i < q.optionsTa!.length) optTa = q.optionsTa![i];
      
      if (optEn.isEmpty && optTa.isEmpty) optEn = options[i];

      String optText = optEn;
      if (optTa.isNotEmpty && optTa != optEn) {
        optText += " / $optTa";
      }

      text += "${numberEmojis[i]} $optText\n";
    }

    text += "\n🎯 *Check Answer & Practice 5000+ Questions:* \n";
    text += "https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book";

    return text;
  }
}
