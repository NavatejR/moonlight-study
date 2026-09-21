import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../shared/widgets/coffee_card.dart';

/// Illustrated empty state with a call-to-action.
///
/// Use when a list or section has no data yet. The illustration is
/// intentionally minimal to match the lo-fi coffee aesthetic.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustration,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? illustration;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: CoffeeColors.caramel.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 40, color: CoffeeColors.caramel),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Fraunces',
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: CoffeeColors.caramel,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pre-built empty state for when there are no notebooks yet.
class EmptyNotebooks extends StatelessWidget {
  const EmptyNotebooks({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.menu_book_outlined,
      title: 'No notebooks yet',
      message:
          'Import some PDFs or documents to get started. Each notebook '
          'groups related study materials together.',
      actionLabel: 'Create notebook',
      onAction: onCreate,
    );
  }
}

/// Pre-built empty state for when a notebook has no documents.
class EmptyDocuments extends StatelessWidget {
  const EmptyDocuments({super.key, required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.note_add_outlined,
      title: 'No documents here',
      message:
          'Import a PDF or image into this notebook to start studying.',
      actionLabel: 'Import document',
      onAction: onImport,
    );
  }
}

/// Pre-built empty state for when there are no flashcards.
class EmptyFlashcards extends StatelessWidget {
  const EmptyFlashcards({super.key, this.onGenerate});

  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.style_outlined,
      title: 'No flashcards yet',
      message:
          'Generate flashcards from your notes and documents, '
          'or add them manually.',
      actionLabel: onGenerate != null ? 'Generate flashcards' : null,
      onAction: onGenerate,
    );
  }
}

/// Pre-built empty state for an empty chat history.
class EmptyChat extends StatelessWidget {
  const EmptyChat({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'Ask anything',
      message:
          'Questions are answered from your library. '
          'The more you study, the more grounded the answers get.',
    );
  }
}

/// Pre-built empty state for when no model is active.
class EmptyModelNotReady extends StatelessWidget {
  const EmptyModelNotReady({super.key, required this.onOpenModels});

  final VoidCallback onOpenModels;

  @override
  Widget build(BuildContext context) {
    return CoffeeCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CoffeeColors.caramel.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.memory_rounded,
                size: 22, color: CoffeeColors.caramel),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No model selected',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pick a model from the Models screen to unlock AI features.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onOpenModels,
            child: const Text('Open Models'),
          ),
        ],
      ),
    );
  }
}
