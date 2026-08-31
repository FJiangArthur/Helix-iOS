// Explicit knowledge graph over conversation data: an on-device, offline,
// fully deterministic projection of questions/answers/transcript turns/saved
// knowledge into nodes and weighted edges.
//
// PURE KOTLIN — no android.* imports, no coroutines, no I/O, no LLM calls. The
// whole builder is a function of its inputs, so it runs in a JVM unit test and
// costs nothing at runtime. Extraction is heuristic (see TermExtractor) and
// deliberately conservative: it would rather miss a topic than fill the graph
// with "the" and "and".
package com.artjiang.helix.knowledge

/** What a node stands for. Drives colour/'shape' in the UI and edge semantics. */
enum class NodeKind {
    /** A recurring term across multiple turns — the backbone of the graph. */
    TOPIC,

    /** A capitalised (multiword) proper name seen in the conversation. */
    ENTITY,

    /** One asked question. */
    QUESTION,

    /** One assistant answer. */
    ANSWER,

    /** A saved KnowledgeItem (fact / project / memory / todo). */
    KNOWLEDGE,

    /** A conversation session that contained the above. */
    SESSION,
}

/** Why two nodes are linked. */
enum class RelationKind {
    /** Two terms appeared in the same turn. Weight = number of co-occurrences. */
    CO_OCCURS,

    /** A term appeared inside this question/answer/knowledge/session node. */
    MENTIONS,

    /** An answer responds to a question. */
    ANSWERS,

    /** A question/answer belongs to a session. */
    CONTAINS,
}

/**
 * One graph vertex.
 *
 * [id] is stable and deterministic for the same input: term nodes use
 * `term:<normalized>`, document nodes use their source id. [weight] is a
 * frequency (occurrence count for terms, mention count for documents) and is
 * what the layout and the UI size nodes by.
 */
data class GraphNode(
    val id: String,
    val label: String,
    val kind: NodeKind,
    val weight: Int,
    /**
     * Free-form detail shown when the node is selected — never logged.
     * For document nodes this is the original text; for terms it is empty.
     */
    val detail: String = "",
)

/**
 * One weighted, undirected-in-spirit edge. [source]/[target] are node ids and
 * are always stored with `source <= target` lexicographically for CO_OCCURS so
 * the same pair can never produce two half-weight edges; directed relations
 * (MENTIONS/ANSWERS/CONTAINS) keep their natural orientation.
 */
data class GraphEdge(
    val source: String,
    val target: String,
    val relation: RelationKind,
    val weight: Int,
)

/**
 * An immutable graph. [nodes] are sorted by descending weight then id, and
 * [edges] by descending weight then source then target then relation — so the
 * whole structure is byte-identical for identical input regardless of hash
 * iteration order. Tests depend on this.
 */
data class KnowledgeGraph(
    val nodes: List<GraphNode>,
    val edges: List<GraphEdge>,
) {
    val isEmpty: Boolean get() = nodes.isEmpty()

    private val byId: Map<String, GraphNode> by lazy(LazyThreadSafetyMode.NONE) {
        nodes.associateBy { it.id }
    }

    fun node(id: String): GraphNode? = byId[id]

    /** Every edge touching [id], strongest first. Order is deterministic. */
    fun edgesOf(id: String): List<GraphEdge> =
        edges.filter { it.source == id || it.target == id }

    /**
     * Neighbours of [id], strongest edge first. This is the "parse along the
     * details" primitive the Knowledge screen uses when a node is tapped.
     */
    fun neighborsOf(id: String): List<GraphNode> =
        edgesOf(id).mapNotNull { edge ->
            val other = if (edge.source == id) edge.target else edge.source
            byId[other]
        }.distinctBy { it.id }

    companion object {
        val EMPTY = KnowledgeGraph(emptyList(), emptyList())
    }
}

/**
 * One unit of conversation input. A "turn" is the co-occurrence window: terms
 * appearing in the same turn get linked. Keeping this a plain data class means
 * the builder never touches repositories and stays unit-testable.
 */
data class ConversationTurn(
    /** Stable id of the document node this turn creates, e.g. a question id. */
    val id: String,
    val text: String,
    val kind: NodeKind,
    /** Optional session this turn belongs to (creates a CONTAINS edge). */
    val sessionId: String? = null,
    val sessionLabel: String? = null,
    /** For ANSWER turns: the question node this answers. */
    val answersId: String? = null,
)

/** Tunables for [KnowledgeGraphBuilder]. All have conservative defaults. */
data class GraphBuildConfig(
    /**
     * A term must appear at least this many times across all turns to become a
     * node. 2 keeps one-off chatter out; entities (capitalised multiword) are
     * admitted at [minEntityFrequency] instead.
     */
    val minTermFrequency: Int = 2,

    /** Proper names are rarer but more meaningful, so they need fewer hits. */
    val minEntityFrequency: Int = 1,

    /** A co-occurrence must repeat this often to become an edge. */
    val minEdgeWeight: Int = 1,

    /** Hard cap on term nodes, strongest first — keeps the layout readable. */
    val maxTermNodes: Int = 60,

    /**
     * Hard cap on document (question/answer/knowledge) nodes, richest first.
     * Terms are capped separately; without this a long history would put one
     * node on screen per transcript line — unreadable, and O(n^2) to lay out.
     * Sessions are never capped: there are few of them and they are the
     * scaffolding the documents hang from.
     */
    val maxDocumentNodes: Int = 80,

    /**
     * Turns with more than this many distinct terms are still indexed, but
     * their co-occurrence pairs are capped to the strongest [maxTermsPerTurn]
     * terms. Prevents one huge transcript turn from creating O(n^2) edges.
     */
    val maxTermsPerTurn: Int = 12,

    /** Include QUESTION/ANSWER/KNOWLEDGE document nodes, not just terms. */
    val includeDocumentNodes: Boolean = true,
)

/**
 * Deterministic, offline term extraction.
 *
 * HEURISTICS (and their limits — see the class doc on [KnowledgeGraphBuilder]):
 *  1. Capitalised runs of 1..4 words that are not sentence-initial-only become
 *     ENTITY candidates ("Even Realities", "Helix").
 *  2. Remaining lowercase tokens of length >= [MIN_TOKEN_LENGTH] that are not
 *     stopwords become TOPIC candidates, after a light suffix normalization
 *     (plural -s / -es) so "glasses"/"glass" do not split.
 *  3. CJK text has no capitalisation or spaces to key off, so CJK runs are
 *     indexed as character bigrams — the same tactic KnowledgeRepository's
 *     searchTerms already uses for retrieval.
 */
internal object TermExtractor {

    const val MIN_TOKEN_LENGTH = 3

    /**
     * English stopwords plus conversational filler. Kept deliberately small
     * and explicit rather than pulled from a dependency: every entry here is
     * a word that would otherwise dominate a spoken-conversation graph.
     */
    val STOPWORDS: Set<String> = setOf(
        "the", "and", "for", "are", "but", "not", "you", "all", "any", "can",
        "her", "was", "one", "our", "out", "day", "get", "has", "him", "his",
        "how", "man", "new", "now", "old", "see", "two", "way", "who", "boy",
        "did", "its", "let", "put", "say", "she", "too", "use", "that", "this",
        "with", "have", "from", "they", "know", "want", "been", "good", "much",
        "some", "time", "very", "when", "come", "here", "just", "like", "long",
        "make", "many", "over", "such", "take", "than", "them", "well", "were",
        "what", "your", "about", "would", "there", "their", "which", "could",
        "should", "because", "going", "really", "think", "thing", "things",
        "yeah", "okay", "right", "sure", "kind", "actually", "basically",
        "maybe", "little", "something", "someone", "anything", "everything",
        "into", "more", "most", "also", "then", "does", "doing", "done",
        "said", "says", "tell", "told", "need", "needs", "look", "looks",
        "will", "shall", "might", "must", "each", "other", "these", "those",
        "being", "where", "while", "still", "even", "ever", "back", "down",
        "only", "same", "both", "after", "before", "again", "onto", "upon",
    )

    private val TOKEN_SPLIT = Regex("[^\\p{L}\\p{N}'’-]+")

    /** True for the CJK blocks that have no word separators. */
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

    /**
     * Light plural folding so "meetings"/"meeting" are one node. Deliberately
     * NOT a real stemmer: over-stemming ("business" -> "busines") is worse
     * than under-merging for a graph a human reads.
     */
    fun normalize(token: String): String {
        val lower = token.lowercase().trim('\'', '’', '-')
        if (lower.length <= 4) return lower
        return when {
            lower.endsWith("ies") && lower.length > 5 -> lower.dropLast(3) + "y"
            lower.endsWith("sses") -> lower.dropLast(2)
            lower.endsWith("ss") -> lower
            lower.endsWith("s") && !lower.endsWith("us") && !lower.endsWith("is") ->
                lower.dropLast(1)

            else -> lower
        }
    }

    /** A candidate term with the surface form to display. */
    data class Term(val key: String, val label: String, val kind: NodeKind)

    /**
     * Extracts terms from one turn, in first-appearance order and deduplicated
     * by key. Order is a function of the text alone, so it is deterministic.
     */
    fun extract(text: String): List<Term> {
        val out = LinkedHashMap<String, Term>()
        for (sentence in text.split(Regex("[.!?\\n;]+"))) {
            extractFromSentence(sentence, out)
        }
        return out.values.toList()
    }

    private fun extractFromSentence(sentence: String, out: MutableMap<String, Term>) {
        val rawTokens = sentence.split(TOKEN_SPLIT).filter { it.isNotEmpty() }
        if (rawTokens.isEmpty()) return

        // Pass 1: capitalised runs -> entities. The first token of a sentence
        // is capitalised by orthography, not by being a name, so a run that
        // starts at index 0 needs length >= 2 to count.
        var i = 0
        val consumed = BooleanArray(rawTokens.size)
        while (i < rawTokens.size) {
            if (!isCapitalised(rawTokens[i])) {
                i++
                continue
            }
            var j = i
            while (j < rawTokens.size && j - i < MAX_ENTITY_WORDS && isCapitalised(rawTokens[j])) {
                j++
            }
            val runLength = j - i
            val sentenceInitial = i == 0
            if (runLength >= 2 || !sentenceInitial) {
                val label = rawTokens.subList(i, j).joinToString(" ")
                val key = "e:" + label.lowercase()
                if (label.length >= 2) {
                    out.getOrPut(key) { Term(key, label, NodeKind.ENTITY) }
                    for (k in i until j) consumed[k] = true
                }
            }
            i = j
        }

        // Pass 2: everything else -> topics (or CJK bigrams).
        for ((index, token) in rawTokens.withIndex()) {
            if (consumed[index]) continue
            if (token.any(::isCjk)) {
                addCjkBigrams(token, out)
                continue
            }
            val norm = normalize(token)
            if (norm.length < MIN_TOKEN_LENGTH) continue
            if (norm in STOPWORDS) continue
            if (norm.all { it.isDigit() }) continue
            val key = "t:$norm"
            out.getOrPut(key) { Term(key, norm, NodeKind.TOPIC) }
        }
    }

    private fun addCjkBigrams(token: String, out: MutableMap<String, Term>) {
        if (token.length <= 2) {
            val key = "t:${token.lowercase()}"
            out.getOrPut(key) { Term(key, token, NodeKind.TOPIC) }
            return
        }
        for (i in 0..token.length - 2) {
            val gram = token.substring(i, i + 2)
            val key = "t:${gram.lowercase()}"
            out.getOrPut(key) { Term(key, gram, NodeKind.TOPIC) }
        }
    }

    private const val MAX_ENTITY_WORDS = 4

    private fun isCapitalised(token: String): Boolean {
        val first = token.firstOrNull() ?: return false
        if (!first.isUpperCase()) return false
        // "I" and all-caps shouting are not names.
        if (token.length < 2) return false
        if (token.all { it.isUpperCase() } && token.length > 4) return false
        return true
    }
}

/**
 * Builds a [KnowledgeGraph] from conversation turns.
 *
 * LIMITS OF THE HEURISTICS (deliberate, documented rather than hidden):
 *  - No part-of-speech tagging, so "running" is a topic like any other word.
 *  - Capitalisation is the only entity signal, so it does nothing for
 *    lowercase-transcribed speech, and a sentence-initial common noun in a
 *    2-word run ("Good morning") can slip through as an ENTITY.
 *  - Plural folding is a two-rule approximation, not a stemmer.
 *  - CJK bigrams are position-based, so they over-generate compared to real
 *    segmentation; the frequency floor is what keeps them in check.
 *  - Co-occurrence is a turn-level bag, so it carries no direction or
 *    causality — an edge means "discussed together", nothing more.
 * These are the price of being offline, instant, and free; an LLM pass would
 * do better and is explicitly out of scope here.
 */
class KnowledgeGraphBuilder(private val config: GraphBuildConfig = GraphBuildConfig()) {

    fun build(turns: List<ConversationTurn>): KnowledgeGraph {
        if (turns.isEmpty()) return KnowledgeGraph.EMPTY

        // --- Pass 1: extract per-turn terms and count global frequency. ---
        val termFrequency = LinkedHashMap<String, Int>()
        val termInfo = LinkedHashMap<String, TermExtractor.Term>()
        val perTurnTerms = ArrayList<List<TermExtractor.Term>>(turns.size)

        for (turn in turns) {
            val terms = TermExtractor.extract(turn.text)
            perTurnTerms.add(terms)
            for (term in terms) {
                termFrequency[term.key] = (termFrequency[term.key] ?: 0) + 1
                termInfo.putIfAbsent(term.key, term)
            }
        }

        // --- Pass 2: apply the frequency floor and the node cap. ---
        val admitted = termFrequency.entries
            .filter { (key, count) ->
                val kind = termInfo.getValue(key).kind
                val floor = if (kind == NodeKind.ENTITY) {
                    config.minEntityFrequency
                } else {
                    config.minTermFrequency
                }
                count >= floor
            }
            // Sort before truncating so the cap keeps the *strongest* terms and
            // ties break by id, never by hash order.
            .sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
            .take(config.maxTermNodes)
            .associate { it.key to it.value }

        val nodes = LinkedHashMap<String, GraphNode>()
        for ((key, count) in admitted) {
            val info = termInfo.getValue(key)
            nodes[key] = GraphNode(
                id = key,
                label = info.label,
                kind = info.kind,
                weight = count,
            )
        }

        // --- Pass 3: document nodes + MENTIONS/CONTAINS/ANSWERS edges. ---
        // Weights accumulate in a sorted map keyed by the canonical edge tuple,
        // so iteration order is already deterministic before the final sort.
        val edgeWeights = LinkedHashMap<EdgeKey, Int>()

        if (config.includeDocumentNodes) {
            // Rank documents by how many admitted terms they carry, then by id
            // for a stable tie-break, and keep only the richest. A document
            // with no admitted term and no session would be an isolated dot.
            val keptDocuments = turns.indices
                .filter { i ->
                    perTurnTerms[i].any { it.key in admitted } || turns[i].sessionId != null
                }
                .sortedWith(
                    compareByDescending<Int> { i -> perTurnTerms[i].count { it.key in admitted } }
                        .thenBy { i -> turns[i].id },
                )
                .take(config.maxDocumentNodes)
                .toHashSet()

            for ((index, turn) in turns.withIndex()) {
                if (index !in keptDocuments) continue
                val mentioned = perTurnTerms[index].filter { it.key in admitted }

                nodes[turn.id] = GraphNode(
                    id = turn.id,
                    label = documentLabel(turn),
                    kind = turn.kind,
                    weight = maxOf(1, mentioned.size),
                    detail = turn.text.trim(),
                )
                for (term in mentioned) {
                    bump(edgeWeights, EdgeKey(turn.id, term.key, RelationKind.MENTIONS))
                }
                val sessionId = turn.sessionId
                if (sessionId != null) {
                    val existing = nodes[sessionId]
                    nodes[sessionId] = GraphNode(
                        id = sessionId,
                        label = turn.sessionLabel ?: "Session",
                        kind = NodeKind.SESSION,
                        weight = (existing?.weight ?: 0) + 1,
                    )
                    bump(edgeWeights, EdgeKey(sessionId, turn.id, RelationKind.CONTAINS))
                }
                val answers = turn.answersId
                if (answers != null) {
                    // Filtered again below against `nodes`, in case the target
                    // question was cut by the document cap.
                    bump(edgeWeights, EdgeKey(turn.id, answers, RelationKind.ANSWERS))
                }
            }
        }

        // --- Pass 4: co-occurrence edges between admitted terms. ---
        for (terms in perTurnTerms) {
            val present = terms
                .filter { it.key in admitted }
                .sortedWith(
                    compareByDescending<TermExtractor.Term> { admitted.getValue(it.key) }
                        .thenBy { it.key },
                )
                .take(config.maxTermsPerTurn)
                .map { it.key }
                .sorted()
            for (a in present.indices) {
                for (b in a + 1 until present.size) {
                    bump(edgeWeights, EdgeKey(present[a], present[b], RelationKind.CO_OCCURS))
                }
            }
        }

        val edges = edgeWeights.entries
            .filter { (key, weight) ->
                // The minimum weight floor applies only to co-occurrence;
                // structural edges are facts, not statistics.
                key.relation != RelationKind.CO_OCCURS || weight >= config.minEdgeWeight
            }
            .filter { (key, _) -> key.source in nodes && key.target in nodes }
            .map { (key, weight) -> GraphEdge(key.source, key.target, key.relation, weight) }
            .sortedWith(
                compareByDescending<GraphEdge> { it.weight }
                    .thenBy { it.source }
                    .thenBy { it.target }
                    .thenBy { it.relation.name },
            )

        val sortedNodes = nodes.values.sortedWith(
            compareByDescending<GraphNode> { it.weight }.thenBy { it.id },
        )

        return KnowledgeGraph(sortedNodes, edges)
    }

    private fun documentLabel(turn: ConversationTurn): String {
        val flat = turn.text.replace(Regex("\\s+"), " ").trim()
        return if (flat.length <= DOCUMENT_LABEL_CHARS) {
            flat
        } else {
            flat.take(DOCUMENT_LABEL_CHARS).trimEnd() + "…"
        }
    }

    private fun bump(map: MutableMap<EdgeKey, Int>, key: EdgeKey) {
        map[key] = (map[key] ?: 0) + 1
    }

    /** Canonicalised so an unordered CO_OCCURS pair never splits into two edges. */
    private data class EdgeKey(val source: String, val target: String, val relation: RelationKind) {
        constructor(a: String, b: String, relation: RelationKind, canonical: Boolean = true) : this(
            source = if (relation == RelationKind.CO_OCCURS && a > b) b else a,
            target = if (relation == RelationKind.CO_OCCURS && a > b) a else b,
            relation = relation,
        )
    }

    private companion object {
        const val DOCUMENT_LABEL_CHARS = 48
    }
}
