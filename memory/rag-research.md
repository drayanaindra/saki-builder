# RAG Deep Research — Comprehensive Knowledge Base

Based on: Marc Haroui's 5-chapter "From Zero to Hero" RAG series, latest 2025-2026 research papers/blogs, and OneIntel codebase analysis.

---

## Marc Haroui's RAG Series — Full Coverage

### Chapter 1: Introduction to RAG
- RAG = connect LLMs to external knowledge at inference time to solve hallucination + knowledge cutoff
- Three core components: **Indexing** → **Retrieval** → **Generation**
- Progression: Naive RAG → Advanced RAG → Modular RAG → Agentic RAG
- Naive RAG limitations: poor chunking loses context, no quality control, no complex query handling

### Chapter 2: Technical Foundations of Text-Only RAG

**Phase 1 — Indexing (Chunking + Embedding)**

| Strategy | How | Best for | Trade-off |
|----------|-----|----------|-----------|
| **Fixed-size** | Split every N chars/tokens | Simple, predictable | Breaks mid-sentence |
| **Recursive** | Hierarchy: `\n\n` → `\n` → `. ` → ` ` | General purpose | Decent but not semantic |
| **Document-structure** | Headings, sections, paragraphs | Structured docs (HTML, MD) | Requires structured input |
| **Semantic** | Embed sentences, split where similarity drops | Dense prose | Expensive; benchmarks show mixed results (Feb 2026: recursive 512-token=69% vs semantic=54%) |
| **Agentic** | LLM evaluates optimal split points | Highest quality | Highest compute cost |
| **Contextual** (Anthropic) | LLM adds context prefix per chunk | Ambiguous chunks | Extra LLM cost but clear winner for retrieval quality |
| **Late chunking** | Embed full doc first, then split | Cross-reference heavy docs | Needs long-context model |
| **Proposition-based** | LLM extracts atomic factual units | Maximum precision | Many small chunks |
| **Parent-child** | Small chunks for retrieval, return parent for context | Balance precision + context | More complex indexing |
| **Adaptive** | Chunk size tailored to content structure | Mixed doc types | Clinical study: 87% vs 13% for fixed-size (p=0.001) |

**Embedding approaches:**
- Bi-encoders: encode query & doc independently (fast, used for retrieval)
- Cross-encoders: process (query, doc) pairs jointly (slow, precise, used for re-ranking)
- Late interaction (ColBERT): per-token embeddings with MaxSim matching

**Phase 2 — Retrieval**
- Dense: semantic embedding similarity
- Sparse (BM25): keyword/term frequency
- Hybrid: dense + sparse combined (best recall + accuracy)

**Phase 3 — Generation**
- Augmented prompts with retrieved context + user query

### Chapter 3: Multimodal RAG
- Expand beyond text: images, audio, video, tables
- Multimodal embedding models: CLIP, Nomic Embed Vision, SigLIP 2, Cohere embed-v4
- ColPali: extends ColBERT late interaction to visual data (PDFs, slides)
- Multimodal late chunking: process at patch/region level, not just textual tokens
- Strategies: text-only extraction (simplest) → multi-vector → vision-first → hybrid

### Chapter 4: Agentic RAG
- Static retrieval → dynamic intelligent agents with adaptive decision-making
- **Agentic Routing**: Smart traffic controller deciding data source (internal KB, web, API)
- **Query Augmentation agents**: Craft smarter queries
- **Data Analysis agents**: Intelligently process retrieved data
- **Single-agent**: One agent handles entire workflow
- **Multi-agent**: Specialized sub-agents (RAG tool, web search, API calls) + coordinator

### Chapter 5: Best Practices for RAG

**Optimization:**
- HyDE for better semantic search alignment
- Metadata filtering to narrow search scope
- Cross-encoder reranking for relevance refinement

**Evaluation (TRIAD framework):**
- Context Relevance (retrieval quality)
- Faithfulness (answer grounded in context?)
- Answer Relevance (addresses the query?)
- Tools: RAGAS, LLM-as-a-Judge (G-Eval), human reviews
- Retriever metrics: Recall@K, MRR
- Generator metrics: ROUGE, groundedness

**Deployment:**
- Latency vs accuracy trade-offs
- Caching strategies
- Scaling considerations

---

## Latest Research 2025-2026

### Embedding Models — Current MTEB Leaderboard

| Model | MTEB | Key Strength |
|-------|------|-------------|
| Cohere embed-v4 | 65.2 | Multilingual, multimodal, MRL + quantization |
| OpenAI text-embedding-3-large | 64.6 | Best production option, $0.13/M tokens |
| OpenAI text-embedding-3-small | — | Budget at $0.02/M tokens |
| BGE-M3 | 63.0 | Open-source; 100+ langs; dense+sparse+ColBERT in one model |
| Jina Embeddings v3 | — | Long context (8K), task-specific LoRA |
| Voyage-3 | — | Code + text, high quality |
| Mixedbread mxbai-embed-large | — | Open-source SOTA |

**Matryoshka Representation Learning (MRL):** Truncate dimensions (3072→512) with minimal accuracy loss. Supported by Cohere embed-v4 and OpenAI text-embedding-3.

### Hybrid Retrieval — Consensus: Three-Way is Optimal

Per IBM research: dense + sparse + full-text is optimal.

**Fusion methods:**
- **RRF**: `score = Σ 1/(k + rank)` (k=60). Best starting point: simple, no tuning, rank-based not score-based.
- **Convex Combination**: Outperforms RRF in benchmarks but requires weight tuning.
- **SPLADE**: Learned sparse retrieval — 94% of BM25 speed with 98% of BERT accuracy.

### Re-ranking — Biggest Quality Win

Cross-encoder reranking: **+20-48% accuracy**, adds 200-500ms latency.

| Reranker | Strength |
|----------|----------|
| Cohere Rerank v4 Pro | +170 ELO over v3.5, 100+ languages |
| mxbai-rerank-large-v2 | Open-source, 1.5B params, RL-trained |
| ms-marco-MiniLM-L-6-v2 | Best speed/accuracy balance |
| BGE-reranker-large | Strong multilingual |

**Pattern:** Retrieve 50-100 → rerank → top 5-10 for LLM.

### Query Optimization Techniques

- **HyDE**: Generate hypothetical answer → embed → search. HyPE (2025) improved precision by up to 42 percentage points. Caveat: hallucinated answers can misdirect.
- **Multi-Query**: Generate 3-5 variants → retrieve each → merge. DMQR-RAG uses 4 rewriting strategies at different information levels.
- **Query Decomposition**: Split complex query into sub-queries, separate retrieval, merge via multi-hop reasoning.
- **Step-Back Prompting**: Abstract/generalize query before retrieval.
- **Query Routing**: RAGRouter (2025) makes RAG-aware routing decisions accounting for how retrieved docs shift LLM knowledge.

### Agentic RAG Patterns

- **Self-RAG**: Model autonomously generates retrieval queries during generation, iteratively refining.
- **CRAG (Corrective RAG)**: Grades each doc as Correct/Ambiguous/Incorrect. Incorrect → trigger web search fallback.
- **Adaptive RAG**: Route by query complexity — simple→direct LLM, standard→RAG, complex→iterative.
- **Context windows (1-2M tokens) vs RAG**: RAG still essential for cost control, freshness, traceability, and datasets exceeding context limits.

### Production Patterns

**Caching:**
- Semantic caching: up to 68.8% LLM cost reduction. Notion/Intercom: 60-80% cache hit rates, latency 150ms→<20ms.
- RAGCache: +7pp accuracy, 30x cache size reduction, 2.7x speedup.

**GraphRAG / Knowledge Graph-Enhanced:**
- Microsoft's GraphRAG: 91% accuracy on complex queries. Cost: 3-5x baseline RAG.
- Best for global/thematic questions where standard RAG struggles.

**RAPTOR (Recursive Abstractive Processing for Tree-Organized Retrieval):**
- Recursively embed, cluster, summarize chunks → hierarchical tree.
- Query retrieves from multiple abstraction levels.
- +20% absolute accuracy on QuALITY benchmark with GPT-4.

**Cost Optimization:**
| Strategy | Impact |
|----------|--------|
| Semantic caching | Up to 68.8% LLM cost reduction |
| Embedding quantization (float8) | 4x storage reduction, <0.3% accuracy loss |
| float8 + PCA combined | 8x total compression |
| Dimension reduction (MRL) | 3072→512 dims minimal quality loss |
| Prompt compression | 15-30% cost reduction |
| Tiered retrieval | Cache → sparse → dense → rerank (skip expensive steps) |

---

## Current OneIntel RAG Implementation

### Architecture Overview
- **Retriever classes**: `SimpleRetriever` (vector), `HybridRetriever` (BM25+dense), `MultiQueryRetriever` (LLM expansion)
- **Orchestrator**: `RAGRetriever` — caching, KB routing, connector resolution, fallback
- **Vector store**: Qdrant with tenant isolation (`tenant_{id}_kb_{kb_id}`)
- **Embedding**: text-embedding-3-small (1536d), OpenAI only, in-memory MD5 cache
- **Chunking**: RecursiveCharacterTextSplitter (1000 chars, 200 overlap)
- **File processing**: PDF (pypdf), DOCX (python-docx), TXT/MD/CSV/JSON/XML/HTML
- **Hybrid**: 70% dense + 30% BM25 weighted average (falls back to vector-only if rank_bm25 unavailable)
- **Multi-query**: 3 LLM-generated variations + heuristic fallback
- **Caching**: 5-min TTL, SHA256 key, LRU max 1000 entries (exact-match only)
- **KB routing**: Embedding similarity to select top-3 relevant KBs when >4 available
- **Learned knowledge**: Auto-extracts facts from conversations, merges into retrieval
- **RAG signals**: Tracks no_results, low_score, user_rephrase for analytics
- **RAG trigger modes**: never, always, conditional (guideline-based), smart (LLM classification)
- **Connector modes**: PUSH, PULL, WebSocket, DIRECT (RAGflow integration)

### Key Files
- `core/rag/retriever.py` — All retriever classes + orchestrator
- `core/rag/vector_store.py` — Qdrant operations
- `core/rag/embeddings.py` — OpenAI embedding service
- `core/rag/pipeline.py` — Document processor + chunking
- `core/rag/file_processor.py` — File format extraction
- `core/rag/connector_resolver.py` — External RAG connector routing
- `core/intelligence/rag_signals.py` — Quality monitoring signals
- `core/intelligence/knowledge_extractor.py` — Learned knowledge from conversations

### Strengths
1. Clean modular architecture with clear separation of concerns
2. Multi-strategy retrieval gives users choice
3. Enterprise-ready: multi-tenant, connectors, rate limiting, audit trail
4. Intelligent KB routing reduces unnecessary queries
5. Learned knowledge enriches future queries automatically
6. Graceful connector fallback
7. Per-agent RAG configuration (strategy, threshold, top-k, cache)
8. RAG quality signal monitoring

---

## Gap Analysis — OneIntel vs Best Practices

| # | Gap | Impact | Effort | Notes |
|---|-----|--------|--------|-------|
| 1 | **No cross-encoder re-ranking** | HIGH | Medium | Single biggest quality win (+20-48%). Add Cohere Rerank or open-source cross-encoder |
| 2 | **No RRF fusion** (weighted avg) | HIGH | LOW | RRF is strictly better. One function change in HybridRetriever |
| 3 | **Single embedding model** | HIGH | Medium | Only text-embedding-3-small. Should support text-embedding-3-large, BGE-M3, Jina |
| 4 | **No contextual chunking** | HIGH | Medium | Raw recursive split. Anthropic's pattern (LLM context prefix) is clear winner |
| 5 | **No parent-child chunking** | MEDIUM | Medium | Can't retrieve precise + return full context |
| 6 | **Fixed hybrid weights** (70/30) | MEDIUM | LOW | Should be configurable or use RRF (eliminates need for weights) |
| 7 | **No HyDE** | MEDIUM | LOW | Generate hypothetical answer for better embedding match |
| 8 | **No query routing** | MEDIUM | Medium | Wastes resources; simple queries don't need multi-query |
| 9 | **No evaluation framework** | HIGH | High | Can't measure improvements. Need RAGAS or equivalent |
| 10 | **Exact-match cache only** | MEDIUM | Medium | Semantic caching would give 60-80% hit rate |
| 11 | **No metadata filtering UI** | MEDIUM | LOW | API supports it but no frontend UX |
| 12 | **No multimodal** | LOW now | High | Tables/images in PDFs lost during extraction |
| 13 | **No CRAG pattern** | MEDIUM | Medium | No quality check on retrieved docs before using |
| 14 | **No Matryoshka/quantization** | LOW | Medium | Cost optimization for scale |
| 15 | **No GraphRAG/RAPTOR** | LOW | High | For complex thematic queries |

---

## Recommended Implementation Roadmap

### Phase 1 — Quick Wins (1-2 weeks)
- [ ] **RRF fusion** in HybridRetriever — replace weighted average with `1/(60+rank)` formula
- [ ] **Cross-encoder re-ranking** — add Cohere Rerank API with open-source fallback
- [ ] **Configurable embedding model** per tenant (text-embedding-3-small/large, custom)
- [ ] **Contextual chunking** — option to prepend doc title + section header to chunks
- [ ] **Metadata filtering** exposed in retrieval UI

### Phase 2 — Quality Improvements (3-4 weeks)
- [ ] **Parent-child chunking** strategy (retrieve small, return parent)
- [ ] **HyDE** query transformation option
- [ ] **Query complexity routing** (simple→direct, standard→RAG, complex→iterative)
- [ ] **Semantic caching** (embedding similarity threshold, not exact match)
- [ ] **RAGAS evaluation** pipeline (faithfulness, relevance, context precision/recall)
- [ ] **CRAG pattern** — grade each retrieved doc before using

### Phase 3 — Advanced (1-2 months)
- [ ] Multiple embedding models (BGE-M3, Jina, Cohere embed-v4)
- [ ] Matryoshka embedding for tiered retrieval
- [ ] Multimodal doc processing (vision model for PDFs with tables/images)
- [ ] GraphRAG / knowledge graph entity extraction
- [ ] RAPTOR tree-organized retrieval

---

## Key Architecture Decisions

1. **Re-ranking**: Cohere Rerank API as default (simple, high quality); open-source ms-marco-MiniLM as fallback
2. **Fusion**: Switch weighted average → RRF (rank-based, no score calibration needed)
3. **Chunking**: Add contextual chunking option (Anthropic pattern) — LLM adds 1-2 sentence context prefix
4. **Embedding**: text-embedding-3-large as upgrade path; BGE-M3 for multilingual; keep text-embedding-3-small as default
5. **Evaluation**: RAGAS integration for automated quality scoring per agent
6. **Caching**: Add semantic cache layer (embedding similarity > 0.95 = cache hit)

## Sources
- Marc Haroui "From Zero to Hero" RAG series (Medium, Jan-Jun 2025)
- Weaviate: Chunking Strategies for RAG
- Firecrawl: Best Chunking Strategies 2026
- PMC: Comparative Evaluation of Advanced Chunking for Clinical Decision Support
- NAACL 2025 Findings: Semantic chunking benchmarks
- Ailog: Best Embedding Models 2025 MTEB Scores
- IBM Research: Three-way hybrid retrieval
- ACM: Analysis of Fusion Functions for Hybrid Retrieval
- Ailog: Cross-Encoder Reranking Study (+20-48%)
- Databricks: Reranking quality improvement research
- ZeroEntropy: Guide to Reranking Models 2026
- Haystack/Zilliz: HyDE documentation
- NVIDIA: Traditional vs Agentic RAG
- arXiv: Agentic RAG Survey (2501.09136)
- RAGAS Documentation: Available Metrics
- TDS: Zero-Waste Agentic RAG Caching Architectures
- arXiv: RAGCache approximate caching
- Microsoft GraphRAG research
- arXiv: RAPTOR paper (2401.18059)
- RAGFlow: RAPTOR integration
- Redis: RAG at Scale 2026
