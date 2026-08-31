import 'package:llamadart/llamadart.dart';

/// What a model can do. A single low-end model may cover several.
enum AiCapability { chat, vision, embeddings, reasoning }

/// A downloadable model offered in the Models screen.
class ModelCatalogEntry {
  const ModelCatalogEntry({
    required this.id,
    required this.name,
    required this.tagline,
    required this.source,
    this.projectorSource,
    required this.capabilities,
    required this.sizeLabel,
    required this.ramLabel,
    required this.speedLabel,
    this.isDefault = false,
    this.icon,
    this.systemPrompt = _defaultSystemPrompt,
  });

  final String id;
  final String name;
  final String tagline;

  /// Hugging Face `hf://` model source (downloaded + cached by llamadart).
  final ModelSource source;

  /// Optional mmproj projector for vision-capable GGUF models.
  final ModelSource? projectorSource;

  final Set<AiCapability> capabilities;
  final String sizeLabel;
  final String ramLabel;
  final String speedLabel;
  final bool isDefault;
  final String? icon;
  final String? systemPrompt;

  bool get isVision => capabilities.contains(AiCapability.vision);

  bool get isEmbedding => capabilities.contains(AiCapability.embeddings);
}

const _defaultSystemPrompt = '''
You are Moonlight, a warm, patient study companion that helps learners
understand their material deeply. Be concise but thorough. When answering
from provided notes or documents, cite the source sections you used. Use
markdown when it helps (headings, lists, formulas).''';

/// STEM-flavored prompt for the math / physics / chemistry models.
const _stemSystemPrompt = '''
You are Moonlight, a warm, patient STEM tutor helping a student learn deeply.
Solve problems step by step and show your working — explain the reasoning
behind each step so it can be learned from, not just copied. Always verify the
final answer. For physics keep units consistent and state your assumptions. For
chemistry balance equations and track moles/units. For math reason exactly and
prefer exact forms over decimal approximations. When answering from provided
notes or documents, cite the source sections you used. Use markdown when it
helps (headings, lists, formulas).''';

/// The catalog of on-device models offered in-app.
///
/// Defaults are intentionally small and CPU-friendly so they also run on
/// older hardware. Bigger, smarter models can be added later without app
/// rebuilds — download and selection happen on-device.
abstract final class ModelCatalog {
  ModelCatalog._();

  static final qwenVl = ModelCatalogEntry(
    id: 'qwen2.5-vl-3b',
    name: 'Qwen2.5-VL-3B',
    tagline: 'Vision + text in one. Reads pages, diagrams and photos.',
    source: ModelSource.parse(
      'hf://llmware/qwen2.5-vl-3b-instruct-gguf/'
      'Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf',
    ),
    projectorSource: ModelSource.parse(
      'hf://llmware/qwen2.5-vl-3b-instruct-gguf/mmproj-F16.gguf',
    ),
    capabilities: const {AiCapability.chat, AiCapability.vision},
    sizeLabel: '~1.9 GB',
    ramLabel: '~3 GB',
    speedLabel: '~12 tok/s',
    isDefault: true,
    icon: 'image_search',
  );

  static final qwenText = ModelCatalogEntry(
    id: 'qwen2.5-1.5b',
    name: 'Qwen2.5-1.5B',
    tagline: 'Tiny & fast. Pure text — great on low-end hardware.',
    source: ModelSource.parse(
      'hf://Qwen/Qwen2.5-1.5B-Instruct-GGUF/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    ),
    capabilities: const {AiCapability.chat},
    sizeLabel: '~1.0 GB',
    ramLabel: '~1.5 GB',
    speedLabel: '~30 tok/s',
    icon: 'article',
  );

  static final deepSeekR1 = ModelCatalogEntry(
    id: 'deepseek-r1-1.5b',
    name: 'DeepSeek-R1-Distill 1.5B',
    tagline: 'Reasoning model — works through math step by step.',
    source: ModelSource.parse(
      'hf://unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/'
      'DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
    ),
    capabilities: const {AiCapability.chat, AiCapability.reasoning},
    sizeLabel: '~1.1 GB',
    ramLabel: '~1.5 GB',
    speedLabel: '~25 tok/s',
    icon: 'psychology',
    systemPrompt: _stemSystemPrompt,
  );

  static final qwenMath = ModelCatalogEntry(
    id: 'qwen2.5-3b',
    name: 'Qwen2.5-3B',
    tagline: 'Balanced 3B generalist, solid on math & science.',
    source: ModelSource.parse(
      'hf://Qwen/Qwen2.5-3B-Instruct-GGUF/'
      'qwen2.5-3b-instruct-q4_k_m.gguf',
    ),
    capabilities: const {AiCapability.chat},
    sizeLabel: '~2.1 GB',
    ramLabel: '~2.6 GB',
    speedLabel: '~18 tok/s',
    icon: 'calculate',
    systemPrompt: _stemSystemPrompt,
  );

  static final phiMini = ModelCatalogEntry(
    id: 'phi-3-mini',
    name: 'Phi-3-mini (4K)',
    tagline: 'MIT small model — strong math & science reasoning for its size.',
    source: ModelSource.parse(
      'hf://microsoft/Phi-3-mini-4k-instruct-gguf/'
      'Phi-3-mini-4k-instruct-q4.gguf',
    ),
    capabilities: const {AiCapability.chat},
    sizeLabel: '~2.3 GB',
    ramLabel: '~2.8 GB',
    speedLabel: '~16 tok/s',
    icon: 'science',
    systemPrompt: _stemSystemPrompt,
  );

  static final smol = ModelCatalogEntry(
    id: 'smolLM2-135m',
    name: 'SmolLM2-135M',
    tagline: 'Ultra-light smoke-test model. Barely wakes the CPU.',
    source: ModelSource.parse(
      'hf://unsloth/SmolLM2-135M-Instruct-GGUF/'
      'SmolLM2-135M-Instruct-Q2_K.gguf',
    ),
    capabilities: const {AiCapability.chat},
    sizeLabel: '~60 MB',
    ramLabel: '~0.2 GB',
    speedLabel: '>100 tok/s',
    icon: 'bolt',
  );

  static final miniLm = ModelCatalogEntry(
    id: 'all-minilm',
    name: 'all-MiniLM-L6-v2',
    tagline: 'Embeddings for instant semantic search over your notes.',
    source: ModelSource.parse(
      'hf://nomic-ai/nomic-embed-text-v1.5-GGUF/nomic-embed-text-v1.5.f16.gguf',
    ),
    capabilities: const {AiCapability.embeddings},
    sizeLabel: '~270 MB',
    ramLabel: '~0.5 GB',
    speedLabel: 'instant',
    icon: 'grain',
  );

  static List<ModelCatalogEntry> get all => [
        qwenVl,
        qwenText,
        deepSeekR1,
        qwenMath,
        phiMini,
        smol,
        miniLm,
      ];

  static ModelCatalogEntry byId(String? id) =>
      all.firstWhere((e) => e.id == id, orElse: () => qwenVl);
}