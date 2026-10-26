// lib/features/spots/presentation/report_comment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import '../../../models/comment_report_model.dart';

class ReportCommentDialog extends StatefulWidget {
  final String commentId;
  final String spotId;
  final String commentText;

  const ReportCommentDialog({
    Key? key,
    required this.commentId,
    required this.spotId,
    required this.commentText,
  }) : super(key: key);

  @override
  State<ReportCommentDialog> createState() => _ReportCommentDialogState();
}

class _ReportCommentDialogState extends State<ReportCommentDialog> {
  final Set<CommentReportReason> _selectedReasons = {};
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // 🆕 Atajo i18n

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.flag, color: Colors.red),
          const SizedBox(width: 8),
          Text(l10n.reportComment),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.commentText,
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.whyReporting,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            ...CommentReportReason.values.map((reason) {
              final isSelected = _selectedReasons.contains(reason);
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Text(reason.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
  reason.getDisplayName(context), // 👈 Ahora es un método y requiere el context
  style: const TextStyle(fontSize: 14),
),
                    ),
                  ],
                ),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedReasons.add(reason);
                    } else {
                      _selectedReasons.remove(reason);
                    }
                  });
                },
              );
            }).toList(),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: l10n.reportDescriptionLabel,
                hintText: l10n.reportDescriptionHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _selectedReasons.isEmpty
              ? null
              : () {
            Navigator.pop(context, {
              'reasons': _selectedReasons.toList(),
              'description': _descriptionController.text.trim(),
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.report),
        ),
      ],
    );
  }
}