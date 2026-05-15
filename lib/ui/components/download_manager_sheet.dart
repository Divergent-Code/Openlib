// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import 'package:openlib/providers/download_providers.dart'
    show
        DownloadTask,
        DownloadStatus,
        downloadNotifierProvider,
        downloadConcurrencyProvider;

/// Shows a bottom sheet listing all download tasks with controls.
Future<void> showDownloadManagerSheet(
    BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _DownloadManagerSheet(),
  );
}

class _DownloadManagerSheet extends ConsumerWidget {
  const _DownloadManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadNotifierProvider);
    final tasks = state.tasks.values.toList();
    final concurrency = ref.watch(downloadConcurrencyProvider);

    final activeCount =
        tasks.where((t) => t.status == DownloadStatus.running).length;
    final pendingCount =
        tasks.where((t) => t.status == DownloadStatus.pending).length;
    final pausedCount =
        tasks.where((t) => t.status == DownloadStatus.paused).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle bar ──────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Downloads',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Badge(
                        label: '$activeCount active',
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      if (pendingCount > 0)
                        _Badge(
                          label: '$pendingCount queued',
                          color: Colors.orange,
                        ),
                      if (pausedCount > 0) ...[
                        const SizedBox(width: 8),
                        _Badge(
                          label: '$pausedCount paused',
                          color: Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Concurrency slider ──────────────────────────────────
              Row(
                children: [
                  Text(
                    'Max concurrent: $concurrency',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Expanded(
                    child: Slider(
                      value: concurrency.toDouble(),
                      min: 1,
                      max: 6,
                      divisions: 5,
                      label: '$concurrency',
                      onChanged: (v) =>
                          ref.read(downloadConcurrencyProvider.notifier).state =
                              v.round(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Task list ───────────────────────────────────────────
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No active downloads',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _DownloadTaskTile(task: tasks[index]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual task tile
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const _DownloadTaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(downloadNotifierProvider.notifier);
    final md5 = task.book.md5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Text(
                  task.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _statusIcon(task.status),
            ],
          ),
          const SizedBox(height: 4),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: 4,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withAlpha(30),
              color: _progressColor(task.status),
            ),
          ),
          const SizedBox(height: 4),

          // Info row
          Row(
            children: [
              Text(
                '${task.formattedDownloadedBytes} / ${task.formattedTotalBytes}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              if (task.errorMessage != null)
                Flexible(
                  child: Text(
                    task.errorMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.red),
                  ),
                ),
              const SizedBox(width: 8),
              // Action buttons
              _actionButton(context, notifier, md5, task.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.running:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case DownloadStatus.pending:
        return const Icon(Icons.queue_sharp, size: 16, color: Colors.orange);
      case DownloadStatus.paused:
        return const Icon(Icons.pause_circle, size: 16, color: Colors.grey);
      case DownloadStatus.complete:
        return const Icon(Icons.check_circle, size: 16, color: Colors.green);
      case DownloadStatus.failed:
        return const Icon(Icons.error, size: 16, color: Colors.red);
      case DownloadStatus.canceled:
        return const Icon(Icons.cancel, size: 16, color: Colors.grey);
    }
  }

  Color _progressColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.running:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.grey;
      case DownloadStatus.complete:
        return Colors.green;
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        return Colors.red;
      case DownloadStatus.pending:
        return Colors.orange;
    }
  }

  Widget _actionButton(
    BuildContext context,
    dynamic notifier,
    String md5,
    DownloadStatus status,
  ) {
    switch (status) {
      case DownloadStatus.running:
        return SizedBox(
          height: 28,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.pause, size: 16),
            label: const Text('Pause', style: TextStyle(fontSize: 11)),
            onPressed: () => notifier.pauseDownload(md5),
          ),
        );
      case DownloadStatus.paused:
        return SizedBox(
          height: 28,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Resume', style: TextStyle(fontSize: 11)),
            onPressed: () => notifier.resumeDownload(md5),
          ),
        );
      case DownloadStatus.pending:
        return SizedBox(
          height: 28,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel', style: TextStyle(fontSize: 11)),
            onPressed: () => notifier.cancelDownload(md5),
          ),
        );
      case DownloadStatus.complete:
      case DownloadStatus.failed:
      case DownloadStatus.canceled:
        return SizedBox(
          height: 28,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Dismiss', style: TextStyle(fontSize: 11)),
            onPressed: () => notifier.dismissTask(md5),
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small badge widget
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
