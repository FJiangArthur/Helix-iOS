// Port of NativeHelix/Sources/HelixG1/G1Protocol.swift.
//
// Wire-format contract for the Even Realities G1 HUD. Everything here is pure
// Kotlin/JVM (no android.* imports) so the byte layouts are unit-testable on
// the JVM and stay byte-for-byte identical to the Swift encoders.
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

    /** 0x70 SIMPLE_TEXT — the hardware-proven paged path. */
    TEXT_PAGE(0x70),

    /** 0x71 = 0x70 SIMPLE_TEXT | 0x01 NEW_CONTENT — replaces the whole screen at once. */
    NEW_CONTENT_PAGE(0x71);

    companion object {
        fun fromRaw(raw: Byte): G1ScreenStatus? = entries.firstOrNull { it.raw == raw }
    }
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
    data class Unknown(val notifyIndex: Int) : G1TouchpadAction
}

/**
 * Pure routing of touchpad notify indices, identical to the Swift
 * `G1TouchpadRouter`.
 *
 * notifyIndex: 0 = exit, 1 = pageBack/Forward (L/R) or evenAI start,
 * 2 = headUp, 3 = headDown, 23 = evenaiStart, 24 = evenaiRecordOver.
 *
 * When an answer is on screen (`hasActiveAnswer`), index 1 becomes page
 * navigation: left = previous page, right = next page. With no active answer,
 * a right-side index 1 starts EvenAI and a left-side index 1 is unhandled
 * (the app shell maps it to pause/resume of transcription).
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
                else -> G1TouchpadAction.Unknown(notifyIndex)
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
    const val MAX_PACKET_LENGTH = 191
    const val HEADER_LENGTH = 9

    /** 191 - 9 = 182 payload bytes per packet on the paged path. */
    const val TEXT_PAGE_CHUNK_SIZE = MAX_PACKET_LENGTH - HEADER_LENGTH

    /**
     * MentraOS-style whole-screen write chunk size. `encodeTextPage` keeps its
     * hardware-proven 182-byte chunks until 176 is validated on device.
     */
    const val WHOLE_SCREEN_CHUNK_SIZE = 176

    /**
     * Hardware-proven paged path: screen_status 0x70 SIMPLE_TEXT, 182-byte
     * chunks, `maxSeq = chunkCount - 1`, `syncSeq` fixed at 0, currentPage
     * 1-based, `new_char_pos` always 0.
     *
     * Empty text still produces exactly one (header-only) packet, matching the
     * Swift `max(payload.count, 1)` stride.
     */
    fun encodeTextPage(
        text: String,
        currentPage: Int = 1,
        maxPage: Int = 1,
    ): List<ByteArray> {
        val payload = text.toByteArray(Charsets.UTF_8)
        val chunks = chunk(payload, TEXT_PAGE_CHUNK_SIZE)
        val maxSeq = maxOf(0, chunks.size - 1).toByte()

        return chunks.mapIndexed { index, chunk ->
            byteArrayOf(
                COMMAND_BYTE,
                0,                                  // syncSeq
                maxSeq,                             // maxSeq = chunkCount - 1
                index.toByte(),                     // seq
                G1ScreenStatus.TEXT_PAGE.raw,       // screen_status
                0,                                  // new_char_pos hi (always 0)
                0,                                  // new_char_pos lo (always 0)
                clampToUByte(currentPage),          // currentPage (1-based)
                clampToUByte(maxPage),
            ) + chunk
        }
    }

    /**
     * MentraOS-style whole-screen write: screen_status 0x71
     * (SIMPLE_TEXT | NEW_CONTENT) replaces the display in one shot, with
     * 176-byte chunks.
     *
     * NOTE — bug-compatible with the Swift source, deliberately:
     *  1. Header byte 2 carries `chunks.size` (the COUNT), not `count - 1`
     *     like the paged path's maxSeq. The Swift test
     *     `testWholeScreenTextUsesNewContentStatusAnd176ByteChunks` locks this
     *     in (3 packets -> byte[2] == 3). Pending hardware validation; do not
     *     "fix" without re-validating against the glasses.
     *  2. currentPage is hard-coded 0 and maxPage 1 — i.e. a 0-based current
     *     page against a 1-based max. The paged path uses 1-based currentPage.
     *  3. `seq` (header byte 1) is the caller-supplied whole-screen sync
     *     counter, not a per-packet sequence; the per-packet index lives in
     *     header byte 3 as usual.
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
                0,                                  // currentPage (see NOTE 2)
                1,                                  // maxPage
            ) + chunk
        }
    }

    /**
     * Splits [payload] into [size]-byte chunks. An empty payload yields a
     * single empty chunk, mirroring Swift's `stride(from: 0, to: max(count, 1))`.
     */
    private fun chunk(payload: ByteArray, size: Int): List<ByteArray> {
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
 * Word-wrapping paginator. Faithful port of Swift `HudPaginator`.
 *
 * NOTE: the Swift implementation is character-count based, NOT a 488px/21pt
 * text-measurement. CLAUDE.md documents the hardware as 488px wide, 21pt font,
 * 5 lines per page; the shipped Swift code approximates that with a single
 * character budget per page (default 120 ≈ 5 lines × ~24 chars). This port
 * keeps the exact Swift behavior so pagination — and therefore packet
 * boundaries and page counts — match between platforms.
 */
class HudPaginator(
    val maxCharactersPerPage: Int = DEFAULT_MAX_CHARACTERS_PER_PAGE,
) {
    companion object {
        /** ~5 lines per page at the G1's 488px / 21pt text metrics. */
        const val LINES_PER_PAGE = 5
        const val DEFAULT_MAX_CHARACTERS_PER_PAGE = 120
    }

    /**
     * Greedy word wrap into pages of at most [maxCharactersPerPage] characters.
     * A single word longer than the budget is emitted on its own page (it can
     * exceed the budget), exactly as in Swift. Whitespace runs collapse to a
     * single space because the Swift version splits on " " and rejoins.
     */
    fun pages(text: String): List<String> {
        val words = text.split(" ").filter { it.isNotEmpty() }
        val pages = mutableListOf<String>()
        var current = ""

        for (word in words) {
            val candidate = if (current.isEmpty()) word else "$current $word"
            if (candidate.length > maxCharactersPerPage && current.isNotEmpty()) {
                pages.add(current)
                current = word
            } else {
                current = candidate
            }
        }

        if (current.isNotEmpty()) pages.add(current)
        return if (pages.isEmpty()) listOf("") else pages
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
    fun textPages(text: String): List<G1HudPage> {
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
                ),
            )
        }
    }
}
