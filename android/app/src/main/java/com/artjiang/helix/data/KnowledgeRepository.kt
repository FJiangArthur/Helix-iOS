// JSON-file backed knowledge store. Port of the knowledge library half of the
// iOS runtime (NativeKnowledgeView's data source).
package com.artjiang.helix.data

import android.content.Context
import com.artjiang.helix.core.KnowledgeBucket
import com.artjiang.helix.core.KnowledgeItem
import com.artjiang.helix.core.SessionSummary
import com.artjiang.helix.knowledge.ConversationTurn
import com.artjiang.helix.knowledge.NodeKind
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.text.Normalizer
import java.util.UUID

enum class AutomaticAnswerQuality(val priority: Int) {
    FAST(0),
    SMART(1),
}

/** One atomic automatic-answer write plus the state needed to undo it safely. */
data class AutomaticAnswerMutation(
    val item: KnowledgeItem,
    val previousItem: KnowledgeItem? = null,
)

/**
 * Knowledge items (projects / facts / memories / todos) persisted as one JSON
 * array in filesDir. Small, bounded data — a whole-file rewrite per mutation is
 * simpler and safer here than a database, and keeps the port dependency-free.
 */
class KnowledgeRepository internal constructor(file: File, scope: CoroutineScope) {

    private val store = JsonFileStore(
        file = file,
        serializer = KnowledgeItem.serializer(),
        scope = scope,
    )

    constructor(context: Context, scope: CoroutineScope) :
        this(File(context.applicationContext.filesDir, FILE_NAME), scope)

    val items: StateFlow<List<KnowledgeItem>> = store.items

    suspend fun add(bucket: KnowledgeBucket, text: String, source: String = "Manual") {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        store.mutate { current ->
            current + KnowledgeItem(
                id = UUID.randomUUID().toString(),
                bucket = bucket,
                text = trimmed,
                source = source,
                createdAtMillis = System.currentTimeMillis(),
            )
        }
    }

    suspend fun remove(id: String) {
        store.mutate { current -> current.filterNot { it.id == id } }
    }

    /**
     * Adds an automatically extracted note once, returning the stored item so
     * the Assistant can show an Undo affordance. Equality is deliberately
     * semantic enough for speech: case, compatibility-width, whitespace and
     * trailing sentence punctuation do not make a second note.
     */
    suspend fun addIfAbsent(
        bucket: KnowledgeBucket,
        text: String,
        source: String,
    ): KnowledgeItem? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null
        val fingerprint = noteFingerprint(trimmed)
        var inserted: KnowledgeItem? = null
        store.mutate { current ->
            val exists = current.any { item ->
                item.bucket == bucket && noteFingerprint(item.text) == fingerprint
            }
            if (exists) {
                // Never rewrite or remove an existing item during an automatic
                // save. It may be a manual/user-owned Q+A memory; first-writer
                // wins and Undo remains scoped only to newly inserted content.
                current
            } else {
                val item = KnowledgeItem(
                    id = UUID.randomUUID().toString(),
                    bucket = bucket,
                    text = trimmed,
                    source = source,
                    createdAtMillis = System.currentTimeMillis(),
                )
                inserted = item
                current + item
            }
        }
        return inserted
    }

    /**
     * Stores one automatic Q&A per normalized question without touching manual
     * memories. A SMART/deeper answer may replace FAST content in place; a
     * later FAST result cannot downgrade SMART. Same-tier changed answers are
     * treated as corrections and update the existing automatic item.
     *
     * The returned previous value makes every update reversible from the same
     * visible Undo receipt used for new inserts.
     */
    suspend fun upsertAutomaticAnswer(
        bucket: KnowledgeBucket,
        text: String,
        quality: AutomaticAnswerQuality,
    ): AutomaticAnswerMutation? {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return null
        val questionFingerprint = automaticAnswerFingerprint(trimmed) ?: return null
        val exactFingerprint = noteFingerprint(trimmed)
        var mutation: AutomaticAnswerMutation? = null
        store.mutate { current ->
            val index = current.indexOfFirst { item ->
                item.bucket == bucket &&
                    isAutomaticAnswerSource(item.source) &&
                    automaticAnswerFingerprint(item.text) == questionFingerprint
            }
            if (index < 0) {
                val item = KnowledgeItem(
                    id = UUID.randomUUID().toString(),
                    bucket = bucket,
                    text = trimmed,
                    source = automaticAnswerSource(quality),
                    createdAtMillis = System.currentTimeMillis(),
                )
                mutation = AutomaticAnswerMutation(item)
                current + item
            } else {
                val existing = current[index]
                val unchanged = noteFingerprint(existing.text) == exactFingerprint
                val existingQuality = automaticAnswerQuality(existing.source)
                val wouldDowngrade = existingQuality.priority > quality.priority
                val upgradesQuality = quality.priority > existingQuality.priority
                if (wouldDowngrade || (unchanged && !upgradesQuality)) {
                    current
                } else {
                    val updated = existing.copy(
                        text = trimmed,
                        source = automaticAnswerSource(quality),
                        createdAtMillis = System.currentTimeMillis(),
                    )
                    mutation = AutomaticAnswerMutation(updated, previousItem = existing)
                    current.toMutableList().also { it[index] = updated }
                }
            }
        }
        return mutation
    }

    /** Undo one automatic insert/update, leaving an independently removed item removed. */
    suspend fun undoAutomaticAnswer(id: String, previousItem: KnowledgeItem?) {
        store.mutate { current ->
            val index = current.indexOfFirst { it.id == id }
            if (previousItem == null) {
                if (index < 0) current else current.filterNot { it.id == id }
            } else if (index < 0) {
                current
            } else {
                current.toMutableList().also { it[index] = previousItem }
            }
        }
    }

    /** Stored contents after initial disk load; used by restart/dedup tests. */
    internal suspend fun loaded(): List<KnowledgeItem> = store.loaded()

    /**
     * Bulk insert for imports: adds only items whose id is not already stored,
     * in a single file rewrite (N add() calls would mean N rewrites). Returns
     * the number added.
     */
    suspend fun addAllIfAbsent(newItems: List<KnowledgeItem>): Int {
        var added = 0
        store.mutate { current ->
            val existing = current.mapTo(HashSet()) { it.id }
            val fresh = newItems.filter { it.text.isNotBlank() && existing.add(it.id) }
            added = fresh.size
            if (fresh.isEmpty()) current else current + fresh
        }
        return added
    }

    /**
     * Simple keyword retrieval used as the engine's knowledge provider.
     * Suspends until the initial disk load has landed, so the first question
     * after launch can't silently miss all saved knowledge.
     */
    suspend fun search(query: String, limit: Int = 3): List<String> {
        val terms = searchTerms(query)
        if (terms.isEmpty()) return emptyList()
        return store.loaded()
            .filter { item -> terms.any { item.text.lowercase().contains(it) } }
            .sortedByDescending { it.createdAtMillis }
            .take(limit)
            .map { it.text }
    }

    internal companion object {
        private const val FILE_NAME = "helix_knowledge.json"
        const val AUTOMATIC_ANSWER_SOURCE_PREFIX = "Helix auto-note · Answer"

        private val automaticAnswerQuestion = Regex(
            "^\\s*(?:q|question)\\s*:\\s*(.*?)\\s*\\n+\\s*(?:a|answer)\\s*:",
            setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
        )

        fun noteFingerprint(text: String): String {
            return normalizeNoteText(text)
        }

        fun automaticAnswerFingerprint(text: String): String? = automaticAnswerQuestion
            .find(text)
            ?.groupValues
            ?.getOrNull(1)
            ?.let(::normalizeNoteText)

        fun isAutomaticAnswerSource(source: String): Boolean =
            source == AUTOMATIC_ANSWER_SOURCE_PREFIX ||
                source.startsWith("$AUTOMATIC_ANSWER_SOURCE_PREFIX · ")

        fun automaticAnswerSource(quality: AutomaticAnswerQuality): String =
            "$AUTOMATIC_ANSWER_SOURCE_PREFIX · ${quality.name}"

        private fun automaticAnswerQuality(source: String): AutomaticAnswerQuality =
            if (source.endsWith("· SMART")) AutomaticAnswerQuality.SMART else AutomaticAnswerQuality.FAST

        private fun normalizeNoteText(text: String): String = Normalizer
            .normalize(text, Normalizer.Form.NFKC)
            .lowercase()
            .trim()
            .replace(Regex("\\s+"), " ")
            .trimStart(
                '"', '\'', '“', '‘', '(', '[', '{', '«', '「', '『', '（',
            )
            .trimEnd(
                '.', '!', '?', '。', '！', '？', '؟',
                '"', '\'', '”', '’', ')', ']', '}', '»', '」', '』', '）',
            )

        /**
         * Projects stored knowledge + saved sessions into the flat turn list
         * the graph builder consumes. Lives here (not in the builder) so the
         * builder stays free of app domain types and unit-testable on its own.
         *
         * A session contributes one turn per transcript line plus one turn for
         * its answer preview, all tagged with the session id so they cluster.
         * Nothing here logs or transmits content.
         */
        /**
         * Turns from the LIVE conversation feed.
         *
         * The saved-session path below can only see sessions the user
         * explicitly saved, and its transcript lines are untyped strings — so
         * every line was tagged QUESTION and no ANSWERS edge could ever form.
         * The feed carries the real kind per entry AND, on answers, the
         * question text they replied to, so this path produces correctly typed
         * nodes and genuine question->answer links.
         *
         * Deterministic: the feed is already append-ordered by id, and answers
         * bind to the most recent QUESTION whose text matches.
         */
        fun feedTurns(feed: List<FeedTurnInput>): List<ConversationTurn> {
            val questionIdByText = LinkedHashMap<String, String>()
            return buildList {
                for (entry in feed.sortedBy { it.id }) {
                    val text = entry.text.trim()
                    if (text.isEmpty()) continue
                    val id = "f:${entry.id}"
                    when (entry.kind) {
                        NodeKind.QUESTION -> {
                            questionIdByText[text] = id
                            add(ConversationTurn(id = id, text = text, kind = NodeKind.QUESTION))
                        }
                        NodeKind.ANSWER -> add(
                            ConversationTurn(
                                id = id,
                                text = text,
                                kind = NodeKind.ANSWER,
                                // Real linkage: the answer records the question
                                // it replied to, so ANSWERS edges are exact
                                // rather than positional guesses.
                                answersId = entry.question?.trim()?.let { questionIdByText[it] },
                            ),
                        )
                        else -> add(ConversationTurn(id = id, text = text, kind = entry.kind))
                    }
                }
            }
        }

        fun conversationTurns(
            knowledge: List<KnowledgeItem>,
            sessions: List<SessionSummary>,
        ): List<ConversationTurn> = buildList {
            // Deterministic input order: the graph builder is order-sensitive
            // for label choice, so sort before feeding it.
            for (item in knowledge.sortedBy { it.id }) {
                add(
                    ConversationTurn(
                        id = "k:${item.id}",
                        text = item.text,
                        kind = NodeKind.KNOWLEDGE,
                    ),
                )
            }
            for (session in sessions.sortedBy { it.id }) {
                val sessionId = "s:${session.id}"
                session.transcriptTurns.forEachIndexed { index, line ->
                    if (line.isNotBlank()) {
                        add(
                            ConversationTurn(
                                id = "$sessionId:t$index",
                                text = line,
                                kind = NodeKind.QUESTION,
                                sessionId = sessionId,
                                sessionLabel = session.title,
                            ),
                        )
                    }
                }
                if (session.answerPreview.isNotBlank()) {
                    add(
                        ConversationTurn(
                            id = "$sessionId:a",
                            text = session.answerPreview,
                            kind = NodeKind.ANSWER,
                            sessionId = sessionId,
                            sessionLabel = session.title,
                        ),
                    )
                }
            }
        }

        /**
         * Unicode-aware tokenization. Java's `\W` is ASCII-only, so the old
         * `split("\\W+")` treated every CJK character as a separator and CJK
         * queries always produced zero terms (RAG silently dead for Chinese —
         * a supported input per QuestionDetector). CJK runs are matched as
         * character bigrams; Latin terms keep a >=3-char noise filter so short
         * names like "Bob" still match.
         */
        fun searchTerms(query: String): List<String> {
            val tokens = query.lowercase()
                .split(Regex("[^\\p{L}\\p{N}]+"))
                .filter { it.isNotEmpty() }
            return buildList {
                for (token in tokens) {
                    if (token.any(::isCjk)) {
                        if (token.length <= 2) add(token)
                        else for (i in 0..token.length - 2) add(token.substring(i, i + 2))
                    } else if (token.length >= 3) {
                        add(token)
                    }
                }
            }.distinct()
        }

        fun isCjk(ch: Char): Boolean = when (Character.UnicodeBlock.of(ch)) {
            Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS,
            Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS_EXTENSION_A,
            Character.UnicodeBlock.CJK_COMPATIBILITY_IDEOGRAPHS,
            Character.UnicodeBlock.HIRAGANA,
            Character.UnicodeBlock.KATAKANA,
            Character.UnicodeBlock.HANGUL_SYLLABLES,
            -> true

            else -> false
        }
    }
}

/**
 * Minimal projection of a conversation feed entry for graph building.
 *
 * Deliberately NOT `FeedEntry` itself: that type lives in `HelixBridge` (the
 * app shell) and this module must stay free of it so the graph pipeline is
 * unit-testable without constructing a bridge.
 */
data class FeedTurnInput(
    val id: Long,
    val kind: NodeKind,
    val text: String,
    val question: String? = null,
)
