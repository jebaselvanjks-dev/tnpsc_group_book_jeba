import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';

class AdminFeedbackScreen extends StatelessWidget {
  const AdminFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "User Feedbacks",
          style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feedbacks')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(Icons.feedback_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "No feedback yet",
                    style: AppTheme.getStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              
              String name = data['userName'] ?? 'Anonymous';
              String email = data['userEmail'] ?? 'No Email';
              String message = data['message'] ?? '';
              Timestamp? timestamp = data['timestamp'] as Timestamp?;
              String dateStr = timestamp != null 
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate()) 
                  : 'No Date';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppTheme.getStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : AppTheme.textMainColor,
                              ),
                            ),
                          ),
                          Text(
                            dateStr,
                            style: AppTheme.getStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: AppTheme.getStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: AppTheme.getStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: isDark ? Colors.white : AppTheme.textMainColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const AppIcon(AppIcons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmDelete(context, doc.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Feedback?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('feedbacks').doc(docId).delete();
              Navigator.pop(context);
            },
            child: Text("Delete", style: AppTheme.getStyle(fontSize: 14, color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
