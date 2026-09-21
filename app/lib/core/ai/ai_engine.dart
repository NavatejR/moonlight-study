import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llamadart/llamadart.dart';

import '../errors/error_handler.dart';
import '../logging/app_logger.dart';
import '../settings/settings_storage.dart';
import 'model_catalog.dart';
import 'soul.dart';

const _defaultSoulFallback =
    'You are Moonlight, a warm, patient study companion that helps learners '
    'understand their material deeply. Be concise but thorough.';

/// One streamed piece of an assistant reply. [content] is the answer text;
/// [thinking] is the model's chain-of-thought (empty for non-reasoning
/// models).
class ChatDelta {
  const ChatDelta({this.content = '', this.thinking = ''});

  final String content;
  final String thinking;

  bool get hasThinking => thinking.isNotEmpty;
}

/// A single on-device AI engine backed by llamadart (llama.cpp).
///
/// Owns the active [LlamaEngine] lifecycle: load, chat stream, stop, swap,
/// and — when disabled — clean unloads so the app stays light.
class AiEngineNotifier extends Notifier<AiEngineState> {
  LlamaEngine? _engine;
  ChatSession? _session;
  StreamSubscription<LlamaCompletionChunk>? _subscription;
  Future<void>? _loadTask;

  @override
  AiEngineState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _session?.reset();
    });
    return const AiEngineState(status: AiStatus.idle);
  }

  bool get _enabled => ref.read(aiEnabledProvider);

  /// Loads the currently selected model (from [activeModelProvider]).
  /// Single-flight: concurrent callers (startup, chat, OCR, embeddings) all
  /// await the same in-flight load instead of loading the model twice.
  Future<void> loadActiveModel() => ensureModelLoaded();

  /// Ensures the active model is loaded, deduplicating concurrent requests.
  /// A failed load clears the guard so the next caller can retry. Safe to call
  /// at any time — after startup, from chat/OCR/embeddings, or from the Models
  /// screen.
  Future<void> ensureModelLoaded() {
    if (_engine != null && _session != null) return Future<void>.value();
    final inFlight = _loadTask;
    if (inFlight != null) return inFlight;
    final task = _loadActiveModel().whenComplete(() {
      _loadTask = null;
    });
    _loadTask = task;
    return task;
  }

  Future<void> _loadActiveModel() async {
    if (!_enabled) {
      await unload();
      return;
    }
    final entry = ref.read(activeModelProvider);
    state = AiEngineState(
      status: AiStatus.loading,
      activeName: entry.name,
    );
    try {
      final engine = LlamaEngine(LlamaBackend());
      final token = ref.read(settingsProvider).value?.huggingFaceToken;
      final options = token != null && token.isNotEmpty
          ? ModelLoadOptions(bearerToken: token)
          : ModelLoadOptions.defaults;
      await engine.loadModelSource(
        entry.source,
        modelParams: const ModelParams(contextSize: 4096, gpuLayers: 0),
        options: options,
        onProgress: (progress) {
          final fraction = progress.fraction;
          if (fraction != null) {
            state = AiEngineState(
              status: AiStatus.downloading,
              activeName: entry.name,
              progress: fraction,
            );
          }
        },
      );
      if (entry.capabilities.contains(AiCapability.vision) &&
          entry.projectorSource != null) {
        await engine.loadMultimodalProjectorSource(
          entry.projectorSource!,
          options: options,
        );
      }
      _engine = engine;
      _session = ChatSession(
        engine,
        systemPrompt: await _systemPromptFor(entry),
      );
      state = AiEngineState(
        status: AiStatus.ready,
        activeName: entry.name,
      );
    } catch (e, stackTrace) {
      logger.error('Failed to load model ${entry.name}',
          error: e, stackTrace: stackTrace);

      state = AiEngineState(
        status: AiStatus.error,
        activeName: entry.name,
        error: ErrorHandler.getUserMessage(e),
      );
      await _disposeEngine();
    }
  }

  /// Composes the system prompt: the Moonlight soul (from `assets/soul.md`)
  /// plus any model-specific rules (e.g. STEM guidance).
  Future<String> _systemPromptFor(ModelCatalogEntry entry) async {
    final soul = ref.read(soulSystemPromptProvider).value ??
        await ref.read(soulSystemPromptProvider.future);
    final prompt = soul ?? _defaultSoulFallback;
    final rules = entry.systemPrompt;
    if (rules == null || rules.trim().isEmpty) return prompt;
    return '$prompt\n\n$rules';
  }


  /// Streams a chat completion as text deltas.
  ///
  /// [ChatDelta.content] is the answer text; [ChatDelta.thinking] carries the
  /// model's chain-of-thought (empty for models without a reasoning mode).
  Stream<ChatDelta> chat(List<LlamaContentPart> parts) async* {
    final session = _session;
    if (session == null || !_enabled) {
      yield const ChatDelta(content: 'The local model is not loaded. Open Models and choose one.');
      return;
    }
    state = AiEngineState(
      status: AiStatus.working,
      activeName: ref.read(activeModelProvider).name,
    );
    try {
      await for (final chunk in session.create(parts)) {
        if (chunk.choices.isEmpty) continue;
        final delta = chunk.choices.first.delta;
        final content = delta.content ?? '';
        final thinking = delta.thinking ?? '';
        if (content.isNotEmpty || thinking.isNotEmpty) {
          yield ChatDelta(content: content, thinking: thinking);
        }
      }
    } finally {
      state = AiEngineState(
        status: AiStatus.ready,
        activeName: ref.read(activeModelProvider).name,
      );
    }
  }

  /// Stops any in-flight generation.
  void stop() {
    _engine?.cancelGeneration();
    _subscription?.cancel();
  }

  /// Runs a single multi-modal completion with a *fresh* conversation, so
  /// per-page OCR calls never pollute the main chat history.
  Stream<String> transcribe(List<LlamaContentPart> parts) async* {
    final engine = _engine;
    if (engine == null || !_enabled) return;
    state = AiEngineState(
      status: AiStatus.working,
      activeName: ref.read(activeModelProvider).name,
    );
    try {
      final fresh = ChatSession(engine, systemPrompt: 'Assistant');
      await for (final chunk in fresh.create(parts)) {
        final delta = chunk.choices.isNotEmpty
            ? chunk.choices.first.delta.content
            : null;
        if (delta != null && delta.isNotEmpty) {
          yield delta;
        }
      }
    } finally {
      state = AiEngineState(
        status: AiStatus.ready,
        activeName: ref.read(activeModelProvider).name,
      );
    }
  }

  /// Computes an embedding for [text] using the loaded embedding model.
  Future<List<double>?> embed(String text) async {
    final engine = _engine;
    if (engine == null || !_enabled) return null;
    try {
      return await engine.embed(text);
    } catch (e, stackTrace) {
      logger.warning('Embedding failed (falling back to keyword scoring)', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Computes embeddings for a batch of texts.
  Future<List<List<double>>?> embedBatch(List<String> texts) async {
    final engine = _engine;
    if (engine == null || !_enabled) return null;
    try {
      return await engine.embedBatch(texts);
    } catch (e, stackTrace) {
      logger.warning('Batch embedding failed (falling back to keyword scoring)', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Unloads the model to free memory.
  Future<void> unload() async {
    _session?.reset();
    _session = null;
    try {
      await _engine?.dispose();
    } catch (e, stackTrace) {
      logger.warning('Failed to dispose engine during unload', error: e, stackTrace: stackTrace);
    }
    _engine = null;
    state = const AiEngineState(status: AiStatus.idle);
    logger.info('Model unloaded');
  }

  Future<void> _disposeEngine() async {
    _session?.reset();
    _session = null;
    try {
      await _engine?.dispose();
    } catch (e, stackTrace) {
      logger.warning('Failed to dispose engine after error', error: e, stackTrace: stackTrace);
    }
    _engine = null;
  }
}

enum AiStatus { idle, loading, downloading, ready, working, error }

class AiEngineState {
  const AiEngineState({
    this.status = AiStatus.idle,
    this.activeName,
    this.progress,
    this.error,
  });

  final AiStatus status;
  final String? activeName;
  final double? progress;
  final String? error;

  bool get isBusy =>
      status == AiStatus.loading ||
      status == AiStatus.downloading ||
      status == AiStatus.working;
}

final aiEngineProvider =
    NotifierProvider<AiEngineNotifier, AiEngineState>(AiEngineNotifier.new);

/// Master switch — when off the engine never loads and the app is a pure
/// study planner.
final aiEnabledProvider =
    NotifierProvider<AiEnabledNotifier, bool>(AiEnabledNotifier.new);

class AiEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) {
    state = value;
    if (!value) {
      // Fire-and-forget unload when disabled.
      Future(() {
        ref.read(aiEngineProvider.notifier).unload();
      });
    }
  }
}

/// Which catalog entry is active (persisted via the model store).
final activeModelProvider =
    NotifierProvider<ActiveModelNotifier, ModelCatalogEntry>(
        ActiveModelNotifier.new);

class ActiveModelNotifier extends Notifier<ModelCatalogEntry> {
  @override
  ModelCatalogEntry build() => ModelCatalog.qwenVl;

  /// Restores the persisted selection without triggering an eager load.
  void setFromDisk(ModelCatalogEntry entry) {
    if (state != entry) state = entry;
  }

  Future<void> select(ModelCatalogEntry entry) async {
    if (state == entry) return;
    state = entry;
    await ref.read(aiEngineProvider.notifier).loadActiveModel();
  }
}