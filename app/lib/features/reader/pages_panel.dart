import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../../core/db/app_database.dart';
import '../../core/theme/colors.dart';
import '../../shared/widgets/loading_skeleton.dart';

/// A vertical strip of page thumbnails on the left side of the PDF viewer.
/// Tapping a thumbnail navigates the main viewer to that page.
class PagesPanel extends StatelessWidget {
  const PagesPanel({
    super.key,
    required this.controller,
    required this.currentPage,
    required this.document,
  });

  final pdfrx.PdfViewerController controller;
  final ValueNotifier<int> currentPage;
  final Document document;

  @override
  Widget build(BuildContext context) {
    if (!controller.isReady) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: 5,
          itemBuilder: (_, _) => const PageThumbnailSkeleton(),
        ),
      );
    }

    final pageCount = controller.pageCount;
    final doc = controller.document;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.view_carousel_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '$pageCount pages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: currentPage,
              builder: (context, activePage, _) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  itemCount: pageCount,
                  itemBuilder: (context, index) {
                    final pageNumber = index + 1;
                    final isActive = pageNumber == activePage;
                    return _PageThumbnail(
                      document: doc,
                      pageNumber: pageNumber,
                      isActive: isActive,
                      onTap: () => controller.goToPage(
                        pageNumber: pageNumber,
                        duration: const Duration(milliseconds: 250),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PageThumbnail extends StatelessWidget {
  const _PageThumbnail({
    required this.document,
    required this.pageNumber,
    required this.isActive,
    required this.onTap,
  });

  final pdfrx.PdfDocument document;
  final int pageNumber;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? CoffeeColors.caramel
                  : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: CoffeeColors.caramel.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                child: pdfrx.PdfPageView(
                  document: document,
                  pageNumber: pageNumber,
                  maximumDpi: 72,
                  backgroundColor: Colors.white,
                  decoration: const BoxDecoration(color: Colors.white),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? CoffeeColors.caramel.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(5),
                  ),
                ),
                child: Text(
                  '$pageNumber',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? CoffeeColors.coffee
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
