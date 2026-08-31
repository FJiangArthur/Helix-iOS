// Port of NativeHelix/Sources/HelixG1/G1Protocol.swift.
//
// Wire-format contract for the Even Realities G1 HUD. Everything here is pure
// Kotlin/JVM (no android.* imports) so the byte layouts are unit-testable on
// the JVM.
//
// NORMATIVE SOURCE: docs/G1_PROTOCOL_SLA.md, derived from the official
// even-realities/EvenDemoApp at commit 3899aac. Where the Swift port and the
// vendor disagree, the vendor wins — this file no longer tracks Swift
// byte-for-byte. Divergences so far: maxSeq is the packet COUNT (SLA-P1) and
// text chunks carry 191 payload bytes (SLA-P2).
//
// The AI/text family is a SINGLE BLE command byte 0x4E (SEND_RESULT). The
// values 0x01/0x30/0x40/0x50/0x60/0x70 are NOT separate commands — they are
// values of the 5th header byte (`screen_status` = ScreenAction | AIStatus).
//
// Packet header: [0x4E, syncSeq, maxSeq, seq, screenStatus,
//                 newCharPosHi, newCharPosLo, currentPage, maxPage, ...data]
//
// `new_char_pos` is hard-coded 0 in every reference implementation (official
// Even Realities demo + community Python SDK). It is NOT an append offset —
// most likely a highlight position. Pagination is 100% phone-driven by
// re-pushing whole pages with an updated currentPage.
package com.artjiang.helix.g1

/**
 * 5th header byte of an 0x4E packet: `ScreenAction | AIStatus`.
 *
 * Mirrors `G1ScreenStatus` in Swift, but also carries the raw values that the
 * Swift enum documents in CLAUDE.md without declaring cases for
 * (NEW_CONTENT_ONLY / MANUAL_MODE / NETWORK_ERROR), per the port brief.
 */
enum class G1ScreenStatus(val raw: Byte) {
    /** 0x01 NEW_CONTENT (AIStatus only, no screen action bits). */
    NEW_CONTENT(0x01),

    /** 0x30 DISPLAYING — firmware auto-advances. */
    DISPLAYING(0x30),

    /** 0x40 DISPLAY_COMPLETE. */
    COMPLETE(0x40),

    /** 0x50 MANUAL_MODE — suppress firmware auto-advance. Helix unused. */
    MANUAL_MODE(0x50),

    /** 0x60 NETWORK_ERROR. Helix unused. */
    NETWORK_ERROR(0x60),

    /** 0x70 SIMPLE_TEXT status bit before NEW_CONTENT is applied. */
    TEXT_PAGE(0x70),

    /** 0x71 = 0x70 SIMPLE_TEXT | 0x01 NEW_CONTENT — every plain-text page on wire. */
    NEW_CONTENT_PAGE(0x71),

    // The official EvenDemoApp always ORs the AI status with type 0x01
    // NEW_CONTENT before it goes on the wire
    // (`EvenAIDataMethod.transferToNewScreen(type, status) => status | type`,
    // always called with type = 0x01). So the AI answer lifecycle never emits a
    // bare 0x30/0x40/0x50 — the wire bytes are 0x31/0x41/0x51. The bare values
    // above are kept because they are the documented bit constants and are
    // asserted by existing tests.

    /** 0x31 = 0x30 DISPLAYING | 0x01 NEW_CONTENT — firmware auto-advance page. */
    AI_DISPLAYING(0x31),

    /**
     * 0x41 = 0x40 DISPLAY_COMPLETE | 0x01 NEW_CONTENT.
     *
     * THE blanking signal: the firmware ends the AI session and clears the HUD
     * only after it receives this. It is only processed once a 0x31 has been
     * seen for the same answer ("The glasses need to have 0x30 before they can
     * process 0x40" — comment in the official `EvenAI.startSendReply`).
     */
    AI_COMPLETE(0x41),

    /** 0x51 = 0x50 MANUAL_MODE | 0x01 NEW_CONTENT — user is paging by touchpad. */
    AI_MANUAL(0x51),

    /** 0x61 = 0x60 NETWORK_ERROR | 0x01 NEW_CONTENT. */
    AI_NETWORK_ERROR(0x61);
}

enum class G1TouchpadSide { LEFT, RIGHT }

/** Result of routing an inbound touchpad `notifyIndex`. */
sealed interface G1TouchpadAction {
    data object Exit : G1TouchpadAction
    data object PreviousPage : G1TouchpadAction
    data object NextPage : G1TouchpadAction
    data object HeadUp : G1TouchpadAction
    data object HeadDown : G1TouchpadAction
    data object EvenAIStart : G1TouchpadAction
    data object EvenAIRecordOver : G1TouchpadAction
    data object ToggleTranscription : G1TouchpadAction
    data class Unknown(val notifyIndex: Int) : G1TouchpadAction
}

/**
 * Pure routing of touchpad notify indices.
 *
 * notifyIndex: 0 = exit, 1 = pageBack/Forward (L/R) or evenAI start,
 * 2 = headUp, 3 = headDown, 23 = evenaiStart, 24 = evenaiRecordOver.
 *
 * When an answer is on screen (`hasActiveAnswer`), index 1 becomes page
 * navigation: left = previous page, right = next page. With no active answer,
 * a right-side index 1 starts EvenAI and a left-side index 1 toggles
 * transcription (the liveListening table in CLAUDE.md).
 *
 * Deviation from the Swift router (deliberate): Swift returns `unknown` for
 * the left-idle tap and lets the app shell re-derive the pause/resume rule
 * from raw indices — which split one routing table across two layers. Here
 * the router owns the whole table.
 */
object G1TouchpadRouter {
    fun route(notifyIndex: Int, side: G1TouchpadSide, hasActiveAnswer: Boolean): G1TouchpadAction =
        when (notifyIndex) {
            0 -> G1TouchpadAction.Exit
            1 -> when {
                hasActiveAnswer ->
                    if (side == G1TouchpadSide.LEFT) G1TouchpadAction.PreviousPage
                    else G1TouchpadAction.NextPage
                side == G1TouchpadSide.RIGHT -> G1TouchpadAction.EvenAIStart
                else -> G1TouchpadAction.ToggleTranscription
            }
            2 -> G1TouchpadAction.HeadUp
            3 -> G1TouchpadAction.HeadDown
            23 -> G1TouchpadAction.EvenAIStart
            24 -> G1TouchpadAction.EvenAIRecordOver
            else -> G1TouchpadAction.Unknown(notifyIndex)
        }
}

/** Builds outbound 0x4E text packets. Byte-identical to Swift `G1PacketEncoder`. */
object G1PacketEncoder {
    const val COMMAND_BYTE: Byte = 0x4E
    const val HEADER_LENGTH = 9

    /**
     * SLA-P2 (MUST): 191 bytes of PAYLOAD per 0x4E packet.
     *
     * Vendor: `lib/services/evenai_proto.dart:8` declares `int len = 191` and
     * `:22-28` slices `data.sublist(seq * len, ...)` — i.e. 191 is the length of
     * the data appended AFTER the 9-byte header, not the total frame length.
     *
     * This constant previously read 191 under the name MAX_PACKET_LENGTH and
     * was then decremented by HEADER_LENGTH to 182, which mis-read the vendor's
     * `len` as a whole-frame budget. Both text paths now carry the vendor's 191
     * payload bytes; the resulting frame is 9 + 191 = 200 bytes, which fits the
     * negotiated MTU of 251 (`docs/G1_BLE_CONNECTION.en.md:58`).
     */
    const val CHUNK_SIZE = 191

    /** Total on-wire frame length for a full packet: 9-byte header + 191 payload. */
    const val MAX_PACKET_LENGTH = HEADER_LENGTH + CHUNK_SIZE

    /** SLA-P2: the paged (0x71/0x31/0x41/0x51) path carries 191 payload bytes. */
    const val TEXT_PAGE_CHUNK_SIZE = CHUNK_SIZE

    /**
     * SLA-P2: the whole-screen (0x71) path carries 191 payload bytes too.
     *
     * This was 176 — a MentraOS-derived value that the Swift source also uses.
     * The vendor's single `len = 191` (`lib/services/evenai_proto.dart:8`)
     * governs every 0x4E text write, so both paths converge on it.
     */
    const val WHOLE_SCREEN_CHUNK_SIZE = CHUNK_SIZE

    /**
     * Paged path: 191-byte chunks (SLA-P2), `maxSeq = chunkCount` (SLA-P1),
     * currentPage 1-based, `new_char_pos` always 0 (SLA-P3).
     *
     * SLA-P1 (MUST): header byte 2 is the TOTAL packet COUNT. The vendor derives
     * it by ceiling division (`lib/services/evenai_proto.dart:18-21`):
     * ```dart
     * int maxSeq = data.length ~/ len;
     * if (data.length % len > 0) { maxSeq++; }
     * ```
     * so a 1-chunk screen sends `maxSeq = 1`. This encoder previously emitted
     * `chunkCount - 1`, inherited from the Swift port; that is a protocol
     * violation and has been corrected. [encodeWholeScreenText] was already
     * correct, and the two paths now agree.
     *
     * [screenStatus] defaults to 0x71 SIMPLE_TEXT | NEW_CONTENT. SLA-A5 requires
     * that action bit for the first, subsequent, and last plain-text page while
     * retaining the 1-based current/max page header. The separate AI lifecycle
     * may explicitly pass 0x31/0x41/0x51.
     *
     * [syncSeq] is a per-SCREEN counter in the official app (`Proto._evenaiSeq`,
     * incremented once per screen push, wrapped to a byte), NOT a per-packet
     * one — every packet of one screen carries the same value. It defaults to 0
     * to preserve the previous behavior.
     *
     * Empty text still produces exactly one (header-only) packet, matching the
     * Swift `max(payload.count, 1)` stride.
     */
    fun encodeTextPage(
        text: String,
        currentPage: Int = 1,
        maxPage: Int = 1,
        screenStatus: G1ScreenStatus = G1ScreenStatus.NEW_CONTENT_PAGE,
        syncSeq: Byte = 0,
    ): List<ByteArray> {
        val payload = text.toByteArray(Charsets.UTF_8)
        val chunks = chunk(payload, TEXT_PAGE_CHUNK_SIZE)
        // SLA-P1: the COUNT, not count - 1 (evenai_proto.dart:18-21).
        val maxSeq = clampToUByte(chunks.size)

        return chunks.mapIndexed { index, chunk ->
            byteArrayOf(
                COMMAND_BYTE,
                syncSeq,                            // syncSeq (per screen)
                maxSeq,                             // maxSeq = chunkCount (SLA-P1)
                index.toByte(),                     // seq
                screenStatus.raw,                   // screen_status
                0,                                  // new_char_pos hi (always 0)
                0,                                  // new_char_pos lo (always 0)
                clampToUByte(currentPage),          // currentPage (1-based)
                clampToUByte(maxPage),
            ) + chunk
        }
    }

    /**
     * Whole-screen write: screen_status 0x71 (SIMPLE_TEXT | NEW_CONTENT)
     * replaces the display in one shot, with 191-byte chunks (SLA-P2).
     *
     * NOTES:
     *  1. Header byte 2 carries `chunks.size` (the COUNT). This is correct per
     *     SLA-P1 / `lib/services/evenai_proto.dart:18-21`, and [encodeTextPage]
     *     now matches it — the two paths no longer disagree. An earlier comment
     *     here called the COUNT a Swift bug replicated "deliberately"; the
     *     vendor source shows the opposite is true, and it was the paged path's
     *     `count - 1` that was wrong.
     *  2. currentPage is hard-coded 0 and maxPage 1 — i.e. a 0-based current
     *     page against a 1-based max. FIXED — see SLA-P5.
     *
     *     The vendor never sends currentPage 0 for real content: every 0x4E
     *     write (the 0x71 text path included) passes
     *     `current_page_num: getCurrentPage()`, and that helper returns 1 when
     *     `_currentLine == 0` (`lib/services/text_service.dart:150-153,68-71`).
     *     A single-page screen is therefore `currentPage = 1, maxPage = 1`.
     *     The 0 originated in Swift's `encodeWholeScreenText` and was inherited
     *     by this port; it is now 1. Not yet validated on hardware.
     *  3. `seq` (header byte 1) is the caller-supplied whole-screen sync
     *     counter, not a per-packet sequence; the per-packet index lives in
     *     header byte 3 as usual (SLA-P4).
     */
    fun encodeWholeScreenText(text: String, seq: Byte = 0): List<ByteArray> {
        val payload = text.toByteArray(Charsets.UTF_8)
        val chunks = chunk(payload, WHOLE_SCREEN_CHUNK_SIZE)
        // Swift: UInt8(clamping: chunks.count) — the count, NOT count - 1.
        val total = clampToUByte(chunks.size)

        return chunks.mapIndexed { index, chunk ->
            byteArrayOf(
                COMMAND_BYTE,
                seq,
                total,
                index.toByte(),
                G1ScreenStatus.NEW_CONTENT_PAGE.raw,
                0,                                  // new_char_pos hi
                0,                                  // new_char_pos lo
                1,                                  // currentPage — 1-based (SLA-P5)
                1,                                  // maxPage
            ) + chunk
        }
    }

    /**
     * Splits [payload] into [size]-byte chunks. An empty payload yields a
     * single empty chunk, mirroring Swift's `stride(from: 0, to: max(count, 1))`.
     * Shared with [G1CommandEncoder]'s chunked-JSON commands so the wire-level
     * chunking rule lives in exactly one place.
     */
    internal fun chunk(payload: ByteArray, size: Int): List<ByteArray> {
        if (payload.isEmpty()) return listOf(ByteArray(0))
        return (payload.indices step size).map { start ->
            payload.copyOfRange(start, minOf(start + size, payload.size))
        }
    }

    /** Swift `UInt8(clamping:)` semantics for a non-negative Int. */
    internal fun clampToUByte(value: Int): Byte =
        value.coerceIn(0, 255).toByte()
}

/**
 * Line-aware word-wrapping paginator for the G1 HUD.
 *
 * ## Why this is line-based and not a flat character budget
 *
 * The hardware display is **488 px wide, 21 pt font, 5 lines per page**
 * (SLA §7; vendor `lib/services/evenai.dart:489-511`, and CLAUDE.md "Text HUD:
 * 488px max width, 21pt font, 5 lines per page"). The vendor wraps with
 * Flutter's `TextPainter.layout(maxWidth: 488)` and then groups the measured
 * lines 5 at a time.
 *
 * The original Swift port — and this Kotlin port after it — collapsed that into
 * a single flat budget of 120 characters per PAGE, with no concept of a line.
 * 120 chars is roughly 2.6 of the 5 available lines, so a "full" page painted
 * only about half the lens. That is the user-visible regression: "the display
 * should support a lot more than just two lines."
 *
 * ## The chars-per-line estimate — read before tuning
 *
 * [DEFAULT_MAX_CHARACTERS_PER_LINE] is an **ESTIMATE**, not a measurement, and
 * it cannot be anything better on this platform:
 *
 *  - The G1 exposes **no text-metrics API**. The firmware renders the UTF-8
 *    payload with its own internal font; nothing comes back over BLE that says
 *    where it broke a line.
 *  - The vendor gets real metrics only because it measures with Flutter's
 *    `TextPainter` against a host-side `TextStyle(fontSize: 21)` — i.e. it
 *    measures a *phone* font and assumes the glasses font matches. We have no
 *    equivalent host-side proxy in this pure-JVM module (no `android.*` imports
 *    here by design, so no `android.graphics.Paint`).
 *
 * Derivation: 488 px / 21 pt. For a proportional face at 21 pt the mean glyph
 * advance for mixed English prose lands near 0.5 em, i.e. ~10.5 px. That gives
 * 488 / 10.5 ≈ 46 characters per line, and 5 × 46 ≈ 230 characters per full
 * page. Wide text (caps, "W"/"M"-heavy) will wrap earlier on the real lens than
 * this estimate predicts; narrow text later.
 *
 * The constant is therefore deliberately **tunable**: if hardware observation
 * shows lines breaking early or late, change
 * [DEFAULT_MAX_CHARACTERS_PER_LINE] and record the observation here with a
 * date. Do not sprinkle magic numbers at call sites.
 */
class HudPaginator(
    /**
     * Characters per rendered line. See the class KDoc — this is an estimate of
     * a hardware property we cannot query, not a protocol constant.
     */
    val maxCharactersPerLine: Int = DEFAULT_MAX_CHARACTERS_PER_LINE,
    /** Rendered lines per HUD page. 5 on the G1 (SLA §7). */
    val linesPerPage: Int = LINES_PER_PAGE,
) {
    companion object {
        /** 5 lines per page at the G1's 488px / 21pt text metrics (SLA §7). */
        const val LINES_PER_PAGE = 5

        /**
         * ~46 chars per line: 488 px / ~10.5 px mean glyph advance at 21 pt.
         * ESTIMATE — see the [HudPaginator] KDoc before changing it.
         */
        const val DEFAULT_MAX_CHARACTERS_PER_LINE = 46

        /**
         * Full-page character budget implied by the line metrics: 5 × 46 = 230.
         *
         * This replaces the old flat `DEFAULT_MAX_CHARACTERS_PER_PAGE = 120`,
         * which filled only ~2.6 of the lens's 5 lines.
         */
        const val DEFAULT_MAX_CHARACTERS_PER_PAGE =
            DEFAULT_MAX_CHARACTERS_PER_LINE * LINES_PER_PAGE
    }

    /**
     * Legacy constructor kept so existing callers and golden tests that think in
     * whole-page budgets keep working. The budget is divided back out into
     * [linesPerPage] lines, so a page still holds what the caller asked for.
     */
    constructor(maxCharactersPerPage: Int) : this(
        maxCharactersPerLine = maxOf(1, maxCharactersPerPage / LINES_PER_PAGE),
        linesPerPage = LINES_PER_PAGE,
    )

    /** Total characters a full page can hold, ignoring the joining newlines. */
    val maxCharactersPerPage: Int get() = maxCharactersPerLine * linesPerPage

    /**
     * Greedy word wrap into LINES of at most [maxCharactersPerLine] characters.
     *
     * This is the primitive; [pages] groups its output. A single word longer
     * than the budget is emitted on its own line and is allowed to overflow it
     * — preserved from the previous page-based behaviour, and matching the
     * vendor, whose `TextPainter` also cannot break inside an unbreakable run
     * without a break opportunity.
     *
     * Whitespace runs collapse to a single space (the input is split on " " and
     * rejoined), as before. Empty input yields a single empty line so callers
     * always get at least one renderable unit.
     */
    fun lines(text: String): List<String> {
        val words = text.split(" ").filter { it.isNotEmpty() }
        val lines = mutableListOf<String>()
        var current = ""

        for (word in words) {
            val candidate = if (current.isEmpty()) word else "$current $word"
            if (candidate.length > maxCharactersPerLine && current.isNotEmpty()) {
                lines.add(current)
                current = word
            } else {
                current = candidate
            }
        }

        if (current.isNotEmpty()) lines.add(current)
        return if (lines.isEmpty()) listOf("") else lines
    }

    /**
     * Groups [lines] into pages of [linesPerPage] lines, joined with "\n".
     *
     * Unchanged API: every existing caller (`G1HudSession`, [G1HudPresenter],
     * `HelixBridge`) still gets `List<String>`, one entry per HUD page. What
     * changed is how much text a page holds — see the class KDoc.
     */
    fun pages(text: String): List<String> {
        val wrapped = lines(text)
        return wrapped.chunked(linesPerPage).map { it.joinToString("\n") }
    }
}

/** One rendered HUD page with its ready-to-write 0x4E packets. */
data class G1HudPage(
    val pageNumber: Int,
    val pageCount: Int,
    val text: String,
    val packets: List<ByteArray>,
) {
    // ByteArray uses identity equals/hashCode; compare contents so tests and
    // state diffing behave like the Swift value type.
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is G1HudPage) return false
        return pageNumber == other.pageNumber &&
            pageCount == other.pageCount &&
            text == other.text &&
            packets.size == other.packets.size &&
            packets.indices.all { packets[it].contentEquals(other.packets[it]) }
    }

    override fun hashCode(): Int {
        var result = pageNumber
        result = 31 * result + pageCount
        result = 31 * result + text.hashCode()
        result = 31 * result + packets.sumOf { it.contentHashCode() }
        return result
    }
}

/** Paginates answer text and packetizes each page. Port of `G1HudPresenter`. */
class G1HudPresenter(
    private val paginator: HudPaginator = HudPaginator(),
) {
    /**
     * Paginates and packetizes [text].
     *
     * [screenStatus]/[syncSeq] default to the vendor plain-text encoding
     * (0x71, syncSeq 0). An explicit AI lifecycle may re-encode a page at
     * 0x31/0x41/0x51 with a live sync counter via [repacketize].
     */
    fun textPages(
        text: String,
        screenStatus: G1ScreenStatus = G1ScreenStatus.NEW_CONTENT_PAGE,
        syncSeq: Byte = 0,
    ): List<G1HudPage> {
        val pages = paginator.pages(text)
        val pageCount = maxOf(1, pages.size)
        return pages.mapIndexed { index, page ->
            val pageNumber = index + 1
            G1HudPage(
                pageNumber = pageNumber,
                pageCount = pageCount,
                text = page,
                packets = G1PacketEncoder.encodeTextPage(
                    text = page,
                    currentPage = pageNumber,
                    maxPage = pageCount,
                    screenStatus = screenStatus,
                    syncSeq = syncSeq,
                ),
            )
        }
    }

    companion object {
        /**
         * Re-encodes an already-paginated page without discarding its page
         * number/count. SLA-A5 requires 0x71 for every plain-text page, not just
         * a 1/1 whole-screen special case; SLA-P5 simultaneously requires the
         * real 1-based current/max header. Explicit AI modes keep their supplied
         * 0x31/0x41/0x51 status on the same paged header.
         */
        fun repacketize(
            page: G1HudPage,
            screenStatus: G1ScreenStatus,
            syncSeq: Byte,
        ): List<ByteArray> = G1PacketEncoder.encodeTextPage(
            text = page.text,
            currentPage = page.pageNumber,
            maxPage = page.pageCount,
            screenStatus = screenStatus,
            syncSeq = syncSeq,
        )
    }
}
