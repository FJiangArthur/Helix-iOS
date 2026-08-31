package com.artjiang.helix.g1

/**
 * Stable, append-only, trailing-window line model for streaming an answer to
 * the G1 HUD so it **scrolls** instead of flashing.
 *
 * ## Why this class exists — the protocol has no append primitive
 *
 * There is no partial-update or append opcode on the G1. `new_char_pos`
 * (header bytes 5-6 of an `0x4E` packet) is hard-coded `0` in **every**
 * reference implementation — the official Even Realities demo and the community
 * Python SDK alike — and is NOT an append offset (SLA-P3,
 * `lib/services/evenai_proto.dart`). Pagination is 100% phone-driven: the phone
 * re-pushes a whole screen with an updated `current_page_num`.
 *
 * So **every write replaces the entire screen**. Smooth scrolling cannot come
 * from appending; it can only come from making each successive whole-screen
 * replacement *stable* — i.e. from each frame differing from the last by
 * exactly one line at the bottom, with everything above it byte-identical.
 * That is the single job of this class.
 *
 * ## What went wrong before
 *
 * The streaming repaint re-paginated the WHOLE accumulated answer from scratch
 * on a 1.2 s timer, then re-presented it, restarting the HUD lifecycle at page
 * 1 every time. Two separate defects follow from that:
 *
 * 1. **The lifecycle restart.** Re-presenting from page 1 on each tick is the
 *    "jumps back to the beginning" half of the bug. Fixed here by never
 *    re-presenting: the stream emits one stable trailing window per completed
 *    line.
 *
 * 2. **The partial-word yank.** This is the subtle one, and the reason the
 *    [tail] buffer exists. Greedy wrapping of a *purely appending* string is in
 *    fact stable for lines that are already full — appending can only extend
 *    the final line. But a streamed answer does not append whole words; it
 *    appends CHARACTERS. So a word arrives incrementally, and the last line
 *    churns as it grows. Concretely, at a 12-char budget:
 *
 *    ```
 *    "alpha beta g"   -> ["alpha beta g"]          <- "g" shown on line 1
 *    "alpha beta ga"  -> ["alpha beta", "ga"]      <- yanked down to line 2
 *    ```
 *
 *    The wearer sees a fragment appear at the end of a line and then jump to
 *    the next one. Withholding a word until a space proves it complete removes
 *    that entirely: a word is placed once, on the line it will stay on.
 *
 * Together these give a display that changes exactly once per completed line,
 * with every previously shown line byte-identical to what it was.
 *
 * ## The model
 *
 *  - Text is wrapped to lines **once, incrementally, append-only**. A line that
 *    has been emitted is frozen forever: it can never be re-wrapped, re-joined,
 *    or re-split by later text. Only the last, still-growing line may change.
 *  - A [Frame] is produced **only when a line is completed** (or when [finish]
 *    flushes the trailing partial line) — not on a timer, and not on every
 *    [update]. That is what makes the display change exactly once per line.
 *  - A frame is the **trailing window**: the last [windowSize] completed lines.
 *    New text appears at the bottom; older lines scroll up and off the top.
 *  - Before the window is full, the frame is whatever exists, top-aligned, with
 *    **no padding** — a two-line answer paints two lines, not two lines plus
 *    three blanks.
 *  - [update] returns `null` when nothing visible changed, so the caller can
 *    skip a redundant BLE write. This matters: each screen is an ACK-gated
 *    left-then-right write (SLA-L1/L2), so a redundant frame costs real airtime
 *    and can stall the stream.
 *
 * Pure Kotlin/JVM — no `android.*` imports, fully unit-testable.
 */
class HudLineStream(
    /** Wraps text to lines. Shares the paginator's 488px/21pt line estimate. */
    private val paginator: HudPaginator = HudPaginator(),
    /**
     * Number of lines visible at once. Defaults to the physical page height
     * ([HudPaginator.LINES_PER_PAGE] = 5). A constructor param so a settings
     * slider can drive it later.
     */
    val windowSize: Int = HudPaginator.LINES_PER_PAGE,
) {
    init {
        require(windowSize >= 1) { "windowSize must be >= 1, was $windowSize" }
    }

    /**
     * One whole-screen paint.
     *
     * @param lines the visible lines, top to bottom — at most [windowSize].
     * @param text  the same lines joined with "\n", ready to hand to
     *              [G1PacketEncoder.encodeWholeScreenText].
     * @param totalLines how many lines the stream has emitted in total,
     *              including ones that have scrolled off the top. Lets a caller
     *              log or display scroll progress without tracking it itself.
     */
    data class Frame(
        val lines: List<String>,
        val totalLines: Int,
    ) {
        val text: String get() = lines.joinToString("\n")
    }

    /** Lines that are complete and frozen. Never mutated after append. */
    private val completed = mutableListOf<String>()

    /**
     * The still-growing line. Not yet frozen: more words may extend it, up to
     * the line budget, at which point it is pushed into [completed].
     */
    private var pending: String = ""

    /**
     * Raw text not yet resolved into a complete word — everything after the last
     * space seen. Held back so a word the model is still emitting cannot be
     * committed to a line and then change.
     */
    private var tail: String = ""

    /** How much of the fed text has already been consumed into lines. */
    private var consumed: Int = 0

    /** Full text seen so far, for the unchanged-input short circuit. */
    private var lastText: String = ""

    /** Whether [finish] has already flushed the trailing partial line. */
    private var finished: Boolean = false

    /** Lines in the last frame handed out, so we can suppress duplicates. */
    private var lastFrameLines: List<String>? = null

    /** Total lines emitted so far, including ones scrolled off the top. */
    val totalLines: Int get() = completed.size

    /**
     * All lines emitted so far, oldest first. Exposed for tests and for callers
     * that want the full transcript rather than the visible window. The
     * append-only invariant means an index, once populated, never changes.
     */
    fun emittedLines(): List<String> = completed.toList()

    /**
     * Feeds the growing answer [text] (the full accumulated string, not a
     * delta) and returns a new [Frame] if — and only if — at least one line was
     * completed by this call. Returns `null` otherwise, including when [text]
     * is unchanged.
     *
     * [text] is expected to grow by appending. If it instead diverges from what
     * was already consumed (a retry, or a different answer), the stream resets
     * itself rather than corrupting the frozen lines; see [reset].
     */
    fun update(text: String): Frame? {
        if (text == lastText) return null

        if (!text.startsWith(consumedPrefix())) {
            // Not an append — the answer was rewritten. Frozen lines cannot be
            // reconciled with it, so start over rather than emit a lie.
            reset()
        }

        lastText = text
        val addition = text.substring(minOf(consumed, text.length))
        consumed = text.length
        if (addition.isEmpty()) return null

        val completedBefore = completed.size
        absorb(addition)
        if (completed.size == completedBefore) return null

        return frameIfChanged()
    }

    /**
     * Flushes the trailing partial line so the last words of an answer are not
     * left unpainted, and returns the final [Frame].
     *
     * Returns `null` if there was nothing pending and the visible window is
     * already what the caller last saw — again so a redundant BLE write can be
     * skipped. Idempotent: a second call returns `null`.
     */
    fun finish(): Frame? {
        if (finished) return null
        finished = true

        // The last word never saw a trailing space, so flush it explicitly.
        val lastWord = tail.trim()
        tail = ""
        if (lastWord.isNotEmpty()) place(lastWord)

        if (pending.isNotEmpty()) {
            completed.add(pending)
            pending = ""
        }
        if (completed.isEmpty()) return null

        return frameIfChanged()
    }

    /** Clears all state so the stream can be reused for the next answer. */
    fun reset() {
        completed.clear()
        pending = ""
        tail = ""
        consumed = 0
        lastText = ""
        finished = false
        lastFrameLines = null
    }

    /**
     * The prefix of the fed text already folded into lines. Used only to detect
     * a non-append rewrite; [lastText] is the authority on what was fed.
     */
    private fun consumedPrefix(): String =
        lastText.substring(0, minOf(consumed, lastText.length))

    /**
     * Folds [addition] into the line buffer, freezing lines as they fill.
     *
     * The tail buffer holds raw text that has not yet resolved into a *complete
     * word*. A word is complete only once a space has been seen after it — until
     * then the next token from the model may extend it ("Th" -> "Thurs" ->
     * "Thursday"), and committing it early would let a later chunk change a line
     * we had already shown.
     *
     * This is the append-only wrap. It only ever *closes* the pending line; it
     * never reopens a frozen one. That is precisely the property that
     * whole-string greedy re-wrapping lacks, and the reason the display scrolls
     * instead of reflowing.
     */
    private fun absorb(addition: String) {
        tail += addition

        while (true) {
            val space = tail.indexOf(' ')
            if (space < 0) break            // no complete word available yet
            val word = tail.substring(0, space)
            tail = tail.substring(space + 1)
            if (word.isNotEmpty()) place(word)
        }
    }

    /** Appends one complete [word] to [pending], freezing the line if it fills. */
    private fun place(word: String) {
        val budget = paginator.maxCharactersPerLine
        val candidate = if (pending.isEmpty()) word else "$pending $word"
        if (candidate.length > budget && pending.isNotEmpty()) {
            completed.add(pending)
            pending = word
        } else {
            pending = candidate
        }
    }

    /**
     * Builds the trailing-window frame, or `null` if it is identical to the
     * last one handed out (nothing for the caller to repaint).
     */
    private fun frameIfChanged(): Frame? {
        val visible = if (completed.size <= windowSize) {
            completed.toList()
        } else {
            completed.subList(completed.size - windowSize, completed.size).toList()
        }
        if (visible == lastFrameLines) return null
        lastFrameLines = visible
        return Frame(lines = visible, totalLines = completed.size)
    }
}
