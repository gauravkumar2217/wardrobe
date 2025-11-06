import 'package:flutter/material.dart';

class AITaggingIndicator extends StatelessWidget {
  final bool isAnalyzing;

  const AITaggingIndicator({
    super.key,
    required this.isAnalyzing,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAnalyzing) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'AI analyzing image...',
            style: TextStyle(
              color: Color(0xFF7C3AED),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

