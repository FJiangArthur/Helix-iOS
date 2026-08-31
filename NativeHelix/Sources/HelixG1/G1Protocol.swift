import Foundation

public enum G1ScreenStatus: UInt8, Sendable {
    case displaying = 0x30
    case complete = 0x40
    case textPage = 0x70
    /// 0x70 SIMPLE_TEXT | 0x01 NEW_CONTENT — replaces the whole screen at once.
    case newContent = 0x71
}

public enum G1TouchpadSide: String, Sendable {
    case left
    case right
}

public enum G1TouchpadAction: Equatable, Sendable {
    case exit
    case previousPage
    case nextPage
    case headUp
    case headDown
    case evenAIStart
    case evenAIRecordOver
    case unknown(Int)
}

public struct G1TouchpadRouter: Sendable {
    public init() {}

    public func route(notifyIndex: Int, side: G1TouchpadSide, hasActiveAnswer: Bool) -> G1TouchpadAction {
        switch notifyIndex {
        case 0:
            return .exit
        case 1:
            if hasActiveAnswer {
                return side == .left ? .previousPage : .nextPage
            }
            return side == .right ? .evenAIStart : .unknown(notifyIndex)
        case 2:
            return .headUp
        case 3:
            return .headDown
        case 23:
            return .evenAIStart
        case 24:
            return .evenAIRecordOver
        default:
            return .unknown(notifyIndex)
        }
    }
}

public struct G1PacketEncoder: Sendable {
    public static let commandByte: UInt8 = 0x4E
    /// The vendor protocol's `len` is the payload budget, not the complete BLE
    /// frame length. The nine-byte 0x4E header is prefixed after chunking.
    public static let maxPayloadLength = 191
    public static let headerLength = 9
    public static let maxPacketLength = headerLength + maxPayloadLength

    public init() {}

    public func encodeTextPage(
        _ text: String,
        syncSequence: UInt8 = 0,
        currentPage: UInt8 = 1,
        maxPage: UInt8 = 1
    ) -> [[UInt8]] {
        let payload = Array(text.utf8)
        let chunkSize = Self.maxPayloadLength
        let chunks = stride(from: 0, to: max(payload.count, 1), by: chunkSize).map { start -> [UInt8] in
            let end = min(start + chunkSize, payload.count)
            return start < end ? Array(payload[start..<end]) : []
        }

        // Despite its name in the vendor implementation, maxSeq is the packet
        // count. Sequence indices remain zero-based.
        let maxSeq = UInt8(clamping: chunks.count)
        return chunks.enumerated().map { index, chunk in
            [
                Self.commandByte,
                syncSequence,
                maxSeq,
                UInt8(index),
                G1ScreenStatus.newContent.rawValue,
                0,
                0,
                max(1, currentPage),
                max(1, maxPage)
            ] + chunk
        }
    }

    /// A single-page convenience using the same hardware-verified direct-text
    /// framing as every other page.
    public func encodeWholeScreenText(_ text: String, seq: UInt8 = 0) -> [[UInt8]] {
        encodeTextPage(text, syncSequence: seq, currentPage: 1, maxPage: 1)
    }
}

public struct HudPaginator: Sendable {
    public let maxCharactersPerPage: Int

    public init(maxCharactersPerPage: Int = 120) {
        self.maxCharactersPerPage = maxCharactersPerPage
    }

    public func pages(for text: String) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var pages: [String] = []
        var current = ""

        for word in words {
            let candidate = current.isEmpty ? word : current + " " + word
            if candidate.count > maxCharactersPerPage, !current.isEmpty {
                pages.append(current)
                current = word
            } else {
                current = candidate
            }
        }

        if !current.isEmpty {
            pages.append(current)
        }
        return pages.isEmpty ? [""] : pages
    }
}

public struct G1HudPage: Equatable, Sendable {
    public var pageNumber: Int
    public var pageCount: Int
    public var text: String
    public var packets: [[UInt8]]

    public init(pageNumber: Int, pageCount: Int, text: String, packets: [[UInt8]]) {
        self.pageNumber = pageNumber
        self.pageCount = pageCount
        self.text = text
        self.packets = packets
    }
}

public struct G1HudPresenter: Sendable {
    private let paginator: HudPaginator
    private let encoder: G1PacketEncoder

    public init(
        paginator: HudPaginator = HudPaginator(),
        encoder: G1PacketEncoder = G1PacketEncoder()
    ) {
        self.paginator = paginator
        self.encoder = encoder
    }

    public func textPages(for text: String) -> [G1HudPage] {
        let pages = paginator.pages(for: text)
        let pageCount = max(1, pages.count)
        return pages.enumerated().map { index, page in
            let pageNumber = index + 1
            return G1HudPage(
                pageNumber: pageNumber,
                pageCount: pageCount,
                text: page,
                packets: encoder.encodeTextPage(
                    page,
                    currentPage: UInt8(clamping: pageNumber),
                    maxPage: UInt8(clamping: pageCount)
                )
            )
        }
    }
}
