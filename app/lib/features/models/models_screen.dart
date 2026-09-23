import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_engine.dart';
import '../../core/ai/chat_backend.dart';
import '../../core/ai/model_catalog.dart';
import '../../core/ai/model_store.dart';
import '../../core/ai/provider_config.dart';
import '../../core/theme/colors.dart';
import '../../shared/widgets/coffee_card.dart';

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ModelCatalog.all;
    final active = ref.watch(activeModelProvider);
    final engine = ref.watch(aiEngineProvider);
    final enabled = ref.watch(aiEnabledProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Models',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Small, efficient, and fully on-device.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _AiToggle(enabled: enabled),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _BackendCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _EngineStatus(
                state: engine,
                enabled: enabled,
                active: active,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.separated(
              itemCount: catalog.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final model = catalog[i];
                return _ModelCard(
                  model: model,
                  isActive: active.id == model.id,
                  busy: engine.isBusy,
                  enabled: enabled,
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _AiToggle extends ConsumerWidget {
  const _AiToggle({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CoffeeCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: CoffeeGradients.espressoDusk,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              enabled ? Icons.auto_awesome_rounded : Icons.power_settings_new_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Local AI', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'The model runs on this device. Nothing leaves.'
                      : 'AI is off. The app works as a plain study planner.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: CoffeeColors.moss,
            onChanged: (value) async {
              final store = await ref.read(modelStoreProvider.future);
              await store.setAiEnabled(value);
              ref.read(aiEnabledProvider.notifier).set(value);
            },
          ),
        ],
      ),
    );
  }
}

class _BackendCard extends ConsumerWidget {
  const _BackendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useExternal = ref.watch(useExternalProviderProvider);
    final config = ref.watch(externalProviderConfigProvider);
    final aiOn = ref.watch(aiEnabledProvider);

    return CoffeeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: CoffeeGradients.latteSunrise,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  useExternal ? Icons.cloud_rounded : Icons.memory_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Backend',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      useExternal
                          ? 'Cloud API — answers sent to ${config.provider.label}'
                          : 'On-device HuggingFace GGUF — nothing leaves this machine',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: useExternal,
                activeThumbColor: CoffeeColors.caramel,
                onChanged: aiOn
                    ? (v) =>
                        ref.read(useExternalProviderProvider.notifier).set(v)
                    : null,
              ),
            ],
          ),
          if (useExternal) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _ProviderDropdown(
              value: config.provider,
              onChanged: (p) => ref
                  .read(externalProviderConfigProvider.notifier)
                  .update(config.copyWith(provider: p)),
            ),
            const SizedBox(height: 12),
            _TextField(
              label: 'Base URL',
              value: config.baseUrl,
              hint: config.provider.defaultBaseUrl,
              onChanged: (v) => ref
                  .read(externalProviderConfigProvider.notifier)
                  .update(config.copyWith(baseUrl: v)),
            ),
            const SizedBox(height: 12),
            _TextField(
              label: 'API key (optional)',
              value: config.apiKey,
              hint: 'sk-...',
              obscure: true,
              onChanged: (v) => ref
                  .read(externalProviderConfigProvider.notifier)
                  .update(config.copyWith(apiKey: v)),
            ),
            const SizedBox(height: 12),
            _TextField(
              label: 'Model',
              value: config.model,
              hint: config.provider.defaultModel,
              onChanged: (v) => ref
                  .read(externalProviderConfigProvider.notifier)
                  .update(config.copyWith(model: v)),
            ),
            const SizedBox(height: 12),
            _TestConnectionButton(config: config),
          ],
        ],
      ),
    );
  }
}

class _ProviderDropdown extends StatelessWidget {
  const _ProviderDropdown({
    required this.value,
    required this.onChanged,
  });

  final ExternalProviderType value;
  final ValueChanged<ExternalProviderType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ExternalProviderType>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Provider',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: ExternalProviderType.values
          .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.obscure = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }
}

class _TestConnectionButton extends ConsumerWidget {
  const _TestConnectionButton({required this.config});

  final ExternalProviderConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: config.isConfigured
            ? () async {
                try {
                  final backend = await ref.read(chatBackendProvider.future);
                  final chunks =
                      await backend('Say OK in one word.').take(5).toList();
                  final reply = chunks.map((c) => c.content).join();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(reply.trim().isNotEmpty
                            ? 'Connection OK — $reply'
                            : 'No response from provider'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            : null,
        icon: const Icon(Icons.wifi_find_rounded, size: 18),
        label: const Text('Test connection'),
      ),
    );
  }
}

class _EngineStatus extends ConsumerWidget {
  const _EngineStatus({
    required this.state,
    required this.enabled,
    required this.active,
  });

  final AiEngineState state;
  final bool enabled;
  final ModelCatalogEntry active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, label, icon) = switch (state.status) {
      AiStatus.idle => (
          CoffeeColors.cacao,
          enabled ? 'Model ready to load' : 'AI is off',
          Icons.power_settings_new_rounded,
        ),
      AiStatus.loading => (
          CoffeeColors.caramel,
          'Loading ${state.activeName ?? active.name}…',
          Icons.hourglass_top_rounded,
        ),
      AiStatus.downloading => (
          CoffeeColors.caramel,
          'Downloading ${state.activeName ?? active.name} · ${((state.progress ?? 0) * 100).toStringAsFixed(0)}%',
          Icons.downloading_rounded,
        ),
      AiStatus.ready => (
          CoffeeColors.moss,
          '${state.activeName ?? active.name} is ready',
          Icons.check_circle_rounded,
        ),
      AiStatus.working => (
          CoffeeColors.sage,
          'Thinking…',
          Icons.psychology_rounded,
        ),
      AiStatus.error => (
          const Color(0xFFB3261E),
          'Load failed — ${state.error ?? 'unknown error'}',
          Icons.error_rounded,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (state.status == AiStatus.error) ...[
              TextButton(
                onPressed: () => ref
                    .read(aiEngineProvider.notifier)
                    .loadActiveModel(),
                child: const Text('Retry'),
              ),
            ] else if (state.status == AiStatus.working)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (state.status == AiStatus.downloading) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.progress ?? 0,
              minHeight: 8,
              backgroundColor: CoffeeColors.latte,
              valueColor:
                  const AlwaysStoppedAnimation(CoffeeColors.caramel),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Large files download once, then run fully offline.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _ModelCard extends ConsumerWidget {
  const _ModelCard({
    required this.model,
    required this.isActive,
    required this.busy,
    required this.enabled,
  });

  final ModelCatalogEntry model;
  final bool isActive;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(aiEngineProvider);
    final isDownloading =
        engine.status == AiStatus.downloading && engine.activeName == model.name;
    final progress = engine.progress ?? 0;

    return CoffeeCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ModelBadge(model: model),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      model.tagline,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isActive)
                const _ActiveBadge()
              else if (model.capabilities.contains(AiCapability.vision))
                const _VisionBadge()
              else if (model.capabilities.contains(AiCapability.reasoning))
                const _ReasoningBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetricChip(icon: Icons.sd_storage_rounded, label: model.sizeLabel),
              const SizedBox(width: 8),
              _MetricChip(icon: Icons.memory_rounded, label: model.ramLabel),
              const SizedBox(width: 8),
              _MetricChip(icon: Icons.bolt_rounded, label: model.speedLabel),
              const Spacer(),
              if (isActive)
                _ActiveLabel()
              else if (isDownloading)
                _DownloadingLabel(progress: progress)
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: enabled && !busy
                      ? () => _select(context, ref)
                      : null,
                  child: const Text('Use'),
                ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: CoffeeColors.latte,
                valueColor: const AlwaysStoppedAnimation(CoffeeColors.caramel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _select(BuildContext context, WidgetRef ref) async {
    final store = await ref.read(modelStoreProvider.future);
    await store.setActiveModelId(model.id);
    await ref.read(activeModelProvider.notifier).select(model);
  }
}

class _ModelBadge extends StatelessWidget {
  const _ModelBadge({required this.model});

  final ModelCatalogEntry model;

  @override
  Widget build(BuildContext context) {
    final icon = switch (model.icon) {
      'image_search' => Icons.image_search_rounded,
      'article' => Icons.article_rounded,
      'bolt' => Icons.bolt_rounded,
      'grain' => Icons.grain_rounded,
      'psychology' => Icons.psychology_rounded,
      'calculate' => Icons.calculate_rounded,
      'science' => Icons.science_rounded,
      _ => Icons.smart_toy_rounded,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: model.capabilities.contains(AiCapability.vision)
            ? CoffeeGradients.espressoDusk
            : CoffeeGradients.caramelGlow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CoffeeColors.sage.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(color: CoffeeColors.moss, shape: BoxShape.circle),
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CoffeeColors.moss,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisionBadge extends StatelessWidget {
  const _VisionBadge();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.visibility_rounded, size: 18, color: CoffeeColors.caramel);
  }
}

class _ReasoningBadge extends StatelessWidget {
  const _ReasoningBadge();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.psychology_rounded, size: 18, color: CoffeeColors.moss);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 15, color: CoffeeColors.cacao),
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 11.5),
      visualDensity: VisualDensity.compact,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      labelPadding: const EdgeInsets.only(left: 4, right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _ActiveLabel extends StatelessWidget {
  const _ActiveLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '● In use',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CoffeeColors.moss),
    );
  }
}

class _DownloadingLabel extends StatelessWidget {
  const _DownloadingLabel({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${(progress * 100).toStringAsFixed(0)}%',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CoffeeColors.caramel),
    );
  }
}