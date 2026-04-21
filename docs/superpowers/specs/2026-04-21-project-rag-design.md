# Project RAG — Design Spec

**Date:** 2026-04-21
**Status:** Draft for review
**Author:** Brainstorm session (Claude + Art)

## Summary

Add a per-project document library with Retrieval-Augmented Generation. Users upload PDF/TXT documents into named projects ahead of time. Before starting a live session, they select an active project. During the session, when Helix detects a question and generates an answer, it first retrieves relevant chunks from the active project's documents via semantic (embedding) search and injects them into the system prompt as priority context. Answers citing project documents include inline citation markers.

A dedicated "Projects" tab on the `LiveHistoryScreen` (third tab alongside Live and History) is the document-management and manual-query surface.

## Goals

- During presentations, when asked for specific facts or numbers that live in uploaded materials, Helix returns answers grounded in those materials rather than model guesses.
- Document management (upload, rename, delete, browse) is a first-class in-app experience, not a settings-menu afterthought.
- Zero impact on the existing conversation pipeline when no project is active. Zero modifications to the existing Buzz service.

## Non-Goals (v1)

- File types other than PDF and plain text. DOCX, Markdown, PPTX, Keynote, images/OCR are out of scope for v1.
- Mid-session project switching. Active project is locked for the duration of a conversation session.
- Hybrid keyword + semantic retrieval. Embeddings only.
- Cross-project retrieval. Each query retrieves from exactly one active project.
- Cloud sync of projects or documents. Local SQLite only.
- Sharing projects between users or devices.

## Decisions (locked from brainstorm)

| Decision | Choice |
|---|---|
| Live-mode integration | Active project enriches auto-answers AND a dedicated tab exists for manual queries |
| File types | PDF + TXT only |
| Retrieval | OpenAI `text-embedding-3-small` semantic search |
| Answer behavior | Project docs take priority; model may fall back to general knowledge; citations distinguish the two |
| Session scope | Sticky project — selected before session, locked for duration |
| Activation UX | Selector chip on Home screen; Projects tab is management-only |
| Per-project tuning | Exposed: chunk size, top-K, similarity threshold |
| Deletion | Soft delete with 7-day recovery window, purged on app launch |
| PDF parser | `syncfusion_flutter_pdf` (pure Dart, no iOS native dependency) |
| Default chunk size | 800 tokens with 100-token overlap, recursive splitter (paragraph → sentence) |
| Default top-K | 5 chunks, similarity threshold 0.3 |
| Size caps | 10 MB per file, 50 documents per project |
| Ingest execution | Background isolate so UI remains responsive |
| Citations | Inline `[1]`, `[2]` markers in response; tap to view source doc + chunk text |

## Architecture

Three layers. Each layer does one thing and does not reach into another's internals.

### Storage layer — Drift / SQLite

Four new tables. No FTS5 or vector extensions — cosine similarity is computed in Dart against in-memory vectors.

**`projects`**
- `id` TEXT PK (UUID v4)
- `name` TEXT NOT NULL
- `description` TEXT NULL
- `created_at` INT (epoch millis)
- `updated_at` INT
- `deleted_at` INT NULL (soft-delete timestamp)
- `chunk_size_tokens` INT DEFAULT 800
- `chunk_overlap_tokens` INT DEFAULT 100
- `retrieval_top_k` INT DEFAULT 5
- `retrieval_min_similarity` REAL DEFAULT 0.3

**`project_documents`**
- `id` TEXT PK (UUID v4)
- `project_id` TEXT NOT NULL FK → `projects.id`
- `filename` TEXT NOT NULL
- `content_type` TEXT (`pdf` or `txt`)
- `byte_size` INT
- `page_count` INT NULL (PDF only)
- `ingested_at` INT
- `deleted_at` INT NULL
- `ingest_status` TEXT (`pending`, `processing`, `ready`, `failed`)
- `ingest_error` TEXT NULL (truncated to 500 chars)

Ingest progress is surfaced through the `IngestEvent` stream, not persisted — ingest runs in an isolate and aborting the app mid-ingest fails the document cleanly, so persisted progress would always be stale.

**`project_document_chunks`**
- `id` TEXT PK (UUID v4)
- `document_id` TEXT NOT NULL FK → `project_documents.id`
- `project_id` TEXT NOT NULL (denormalized for faster project-scoped queries)
- `chunk_index` INT (order within document)
- `text` TEXT NOT NULL
- `token_count` INT
- `page_start` INT NULL (PDF only)
- `page_end` INT NULL (PDF only)

**`project_document_chunk_vectors`**
- `chunk_id` TEXT PK FK → `project_document_chunks.id`
- `embedding` BLOB (6,144 bytes — 1,536 float32 values for `text-embedding-3-small`)
- `embedding_model` TEXT (`text-embedding-3-small` for v1, room to swap later)

Kept as a separate table to keep the chunks table small for fast metadata queries, and to simplify future swap of embedding model without schema migration.

**Foreign keys and cascades**
- `project_documents.project_id` → `projects.id` ON DELETE CASCADE
- `project_document_chunks.document_id` → `project_documents.id` ON DELETE CASCADE
- `project_document_chunks.project_id` → `projects.id` ON DELETE CASCADE (denormalized FK for safety)
- `project_document_chunk_vectors.chunk_id` → `project_document_chunks.id` ON DELETE CASCADE

Cascades only fire on *hard* delete (i.e., the 7-day purge). Soft delete does not cascade — it just sets `deleted_at` on the project or document row. Retrieval and list queries filter `deleted_at IS NULL`.

**Indexes**
- `project_documents (project_id, deleted_at)` — fast list-by-project that filters deleted (also serves `project_id`-only lookups)
- `project_document_chunks (project_id)` — load-all-vectors for a project
- `project_document_chunks (document_id)` — cascade-delete chunks on doc delete
- `projects (deleted_at)` — purge scan

**Cosine similarity computed in Dart.** For v1 scale (≤50 docs × ~100 chunks = 5,000 vectors × 6 KB = 30 MB max per project), loading all vectors into memory and computing cosine in-process is fast enough (sub-100ms on device). If we outgrow this, `sqlite-vss` or equivalent is a drop-in upgrade since embeddings are already stored as BLOBs.

### Service layer — Dart

All new services, no modifications to existing services except the one hook in `ConversationEngine`.

**`ProjectsService` (singleton)**
Public API:
- `Stream<List<Project>> watchProjects()` — live-updating list for the Projects tab
- `Future<Project> createProject({required String name, String? description})`
- `Future<void> updateProject(Project updated)`
- `Future<void> softDeleteProject(String projectId)` — sets `deleted_at`
- `Future<void> undoDelete(String projectId)` — clears `deleted_at` if within 7 days
- `Future<void> purgeExpiredSoftDeletes()` — called on app launch

**`DocumentIngestService`**
Runs in a background isolate. Public API:
- `Stream<IngestEvent> ingestDocument({required String projectId, required String filePath, required String filename})`
- `Stream<IngestEvent> events` — global stream of all in-flight ingest progress for UI badges

`IngestEvent` variants: `Started`, `ExtractingText(progress)`, `Chunking`, `Embedding(chunksDone, totalChunks)`, `Completed(documentId)`, `Failed(error)`.

Pipeline:
1. Copy source file into app documents directory (immutable reference copy)
2. Extract text — `syncfusion_flutter_pdf` for PDFs, direct read for TXT
3. Recursive chunk: split by paragraph, then sentence if paragraph > chunk_size, preserve overlap
4. Batch-embed via OpenAI API (batch of 100 chunks per request, up to the API's ~8KB per-input limit)
5. Persist chunks + vectors atomically per document (transaction)
6. Mark `ingest_status = 'ready'`

On failure at any step: set `ingest_status = 'failed'`, persist `ingest_error`, surface in UI with a "Retry" action.

**`DocumentEmbeddingStore`**
Internal service owned by `ProjectRagService`. Responsible for loading and caching vectors.
- `Future<List<ChunkWithVector>> loadProjectVectors(String projectId)` — loads all non-deleted vectors for a project into memory
- Maintains an LRU cache keyed by `projectId` with a TTL; invalidates the cached project when its documents change
- `double cosineSimilarity(Float32List a, Float32List b)` — dot product / (||a|| × ||b||)

**`ProjectRagService` (singleton)**
Public API:
- `Future<RetrievalResult> retrieve({required String projectId, required String query, int? topKOverride, double? thresholdOverride})`

`RetrievalResult` contains:
- `chunks` — `List<RetrievedChunk>` with `chunkText`, `similarity`, `documentId`, `documentFilename`, `pageStart`, `pageEnd`, `chunkId`
- `queryEmbedding` — the computed embedding (for logging/debugging)
- `totalChunksSearched` — observability
- `durationMs`

Retrieval flow:
1. Embed query via OpenAI `text-embedding-3-small`
2. Load project vectors from `DocumentEmbeddingStore`
3. Cosine-rank all chunks against query embedding
4. Filter by similarity threshold, take top-K
5. Return ranked list with source metadata

**`ActiveProjectController` (singleton)**
Holds the currently-selected-for-live project ID. Backed by `SettingsManager` so selection persists across app restarts. Emits a stream on change.
- `String? get activeProjectId`
- `Stream<String?> get activeProjectStream`
- `Future<void> setActive(String? projectId)`

### Integration hook — `ConversationEngine`

Single surgical change in `_generateResponse`. Before calling `LlmService.streamResponse`:

```
if (ActiveProjectController.instance.activeProjectId != null) {
  final retrieval = await ProjectRagService.instance.retrieve(
    projectId: activeProjectId,
    query: detectedQuestion.text,
  );
  if (retrieval.chunks.isNotEmpty) {
    systemPrompt = _prependProjectContext(systemPrompt, retrieval);
    citationSources = retrieval.chunks; // passed through to response metadata
  }
}
```

`_prependProjectContext` inserts a clearly-delimited `PROJECT CONTEXT` block at the top of the system prompt with:
- One paragraph of instruction: "The following excerpts are from the user's project documents. Prefer facts from these excerpts over your general knowledge. Cite with `[N]` markers matching the numbered excerpts below. If the excerpts do not contain the answer, answer from general knowledge without citations."
- Numbered excerpts `[1] … [5]` with filename + page refs

If retrieval returns zero chunks above threshold, no context is injected and the model behaves exactly as today. Citations are suppressed.

On the response stream, the existing `aiResponseStream` is unchanged — the citation markers just appear inline as text. A new `projectCitationsStream` on `ConversationEngine` emits the resolved citation sources (chunk text + document name) whenever a retrieval happens. `HomeScreen` listens to this stream and renders tap targets beneath the answer that open a sheet showing the cited chunk.

## UI

### Active project chip — `HomeScreen`

A compact chip between the transcript area and the mode selector. Two states:

- **No project selected:** label "No project", subtle neutral style, tap opens a project picker sheet.
- **Project selected:** label "Project: {name}", accent border, small dot indicator, tap opens a picker sheet where you can change or clear.

The picker sheet lists all non-deleted projects, shows their document count, and includes a "Manage projects" action that deep-links to the Projects tab.

### Projects tab — `LiveHistoryScreen`

Third tab added to the existing `DefaultTabController`. Contains two sub-views, switched by a segmented control at the top:

**"Projects" view (default)**
- FAB or top-bar action: "New project"
- List of projects (card per project) showing name, description, document count, total size, last-modified
- Tap a card → project detail screen

**"Recently deleted" view** (hidden if empty)
- Same card layout but muted
- Each card shows days-until-purge and an "Undo" action

### Project detail screen

Pushed from the Projects tab. Contains:

- Header: project name (editable), description
- "Active for live" indicator if this project is the current `ActiveProjectController.activeProjectId`; button to set or clear
- Documents list with status (ingesting / ready / failed)
- Upload action — opens iOS document picker filtered to PDF + TXT
- Per-document actions: rename, delete (soft), retry ingest (if failed)
- Settings sheet: chunk size, overlap, top-K, similarity threshold with defaults pre-filled and a "Reset to defaults" action
- "Ask this project" action (in v1) — opens an inline query box that uses `ProjectRagService.retrieve` and streams an answer (reuses `LlmService.streamResponse` with the same prompt template as live mode). Included in v1 because the service layer already exposes it at no additional cost.

## Error handling and edge cases

- **OpenAI embedding API failure on ingest:** mark document `ingest_status = 'failed'`, surface in UI with Retry. Chunks already successfully embedded in this document are rolled back (atomic per-document transaction).
- **OpenAI embedding API failure on query:** if active project is set but retrieval call fails, proceed without project context, log error, surface a transient snackbar. User still gets an answer from general knowledge.
- **API key not configured:** Projects tab shows a banner "OpenAI API key required for document search" with a link to Settings. Upload is disabled.
- **File exceeds 10 MB or project has 50 docs:** friendly error in the upload flow, no partial state.
- **Corrupt PDF:** `syncfusion_flutter_pdf` throws → mark document `failed` with a human-readable error.
- **Empty PDF (text extraction yields no content):** mark `failed` with message "No text could be extracted — scanned PDFs require OCR which is not supported in v1."
- **Active project deleted while live session running:** the session continues, but retrieval returns empty (graceful degradation). Chip shows "No project."
- **Project setting changed while ingest is in progress:** new setting applies to subsequent uploads only. No re-chunking of existing documents (the user can delete and re-upload if they want re-chunking).

## Observability

- All retrieval calls logged with `durationMs`, `totalChunksSearched`, `chunksReturned`, `topSimilarity`.
- All embedding API calls logged with token count and latency; aggregated into the existing cost tracker (`ConversationAiCostEntries` table already tracks operation types — add `document_embedding` and `query_embedding` variants).
- Ingest failures logged with full error and file metadata.

## Testing strategy

- **Unit tests:** chunker (boundary cases, overlap correctness, token counting), cosine similarity, recursive splitter on edge inputs (empty doc, single-line doc, doc larger than context window)
- **Integration tests:** end-to-end ingest of a small test PDF, verify chunk count and retrieval against a known query
- **Widget tests:** Projects tab renders list correctly, active project chip reflects controller state
- **Mock tests:** `ConversationEngine` with and without active project, verify prompt injection happens exactly once and only when chunks clear threshold
- **No live API tests in CI** — embedding calls are mocked; manual smoke test on simulator before PR

## Dependencies to add

- `syncfusion_flutter_pdf` — PDF text extraction. Pure Dart, MIT-licensed community edition (free for the scope we're using).
- `file_picker` — if not already present, for iOS document picker UX. Check `pubspec.yaml` first.
- No other new packages. OpenAI API is already integrated via `OpenAIProvider`; embeddings endpoint uses the same auth path.

## Migration

Pure additive migration. Four `CREATE TABLE` statements, a few `CREATE INDEX`, no changes to existing tables. The existing `ConversationAiCostEntries` table gets two new values in its `operation_type` column, which is a TEXT field so no schema change is required — just updated enum in Dart.

## Open questions (defer to plan)

- Exact token-counting strategy for chunking (tiktoken Dart port vs. approximation by 4 chars/token). Plan phase will pick; default to 4-chars-per-token approximation unless a Dart tiktoken port turns out to be trivial.

## Out-of-scope follow-ups

These are intentionally deferred:

- OCR for scanned PDFs
- DOCX, PPTX, Keynote, Markdown, images
- Cloud sync / multi-device
- Cross-project retrieval
- Hybrid FTS5 + embeddings
- Mid-session project switching
- Automatic re-chunking when settings change
- Sharing projects with other users
