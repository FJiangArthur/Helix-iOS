import Foundation
import HelixG1
import Observation

@MainActor
@Observable
public final class NativeG1DeviceState {
    public private(set) var leftLensConnected = false
    public private(set) var rightLensConnected = false
    public private(set) var hasActiveAnswer = false
    public private(set) var currentPageIndex = 0
    public private(set) var hudPages: [G1HudPage] = []
    public private(set) var lastTouchpadAction: G1TouchpadAction?
    public private(set) var sentPacketCount = 0
    public private(set) var lastPacketHeader: [UInt8] = []
    public private(set) var eventLog: [String] = []

    private let hudPresenter: G1HudPresenter
    private let touchpadRouter: G1TouchpadRouter

    public init(
        hudPresenter: G1HudPresenter = G1HudPresenter(),
        touchpadRouter: G1TouchpadRouter = G1TouchpadRouter()
    ) {
        self.hudPresenter = hudPresenter
        self.touchpadRouter = touchpadRouter
    }

    public var connectionSummary: String {
        switch (leftLensConnected, rightLensConnected) {
        case (true, true): return "Dual connected"
        case (true, false): return "Left only"
        case (false, true): return "Right only"
        case (false, false): return "Disconnected"
        }
    }

    public var currentPageSummary: String {
        guard !hudPages.isEmpty else { return "No HUD pages" }
        return "\(currentPageIndex + 1) of \(hudPages.count)"
    }

    public var lastTouchpadSummary: String {
        guard let lastTouchpadAction else { return "Ready" }
        return lastTouchpadAction.displayTitle
    }

    public func setConnection(left: Bool, right: Bool) {
        leftLensConnected = left
        rightLensConnected = right
        eventLog.append("connection:\(connectionSummary)")
    }

    public func presentText(_ text: String) {
        hudPages = hudPresenter.textPages(for: text)
        currentPageIndex = 0
        hasActiveAnswer = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sentPacketCount = hudPages.flatMap(\.packets).count
        lastPacketHeader = hudPages.first?.packets.first.map { Array($0.prefix(9)) } ?? []
        eventLog.append("hud:\(hudPages.count)")
    }

    public func clearHud() {
        hudPages = []
        currentPageIndex = 0
        hasActiveAnswer = false
        sentPacketCount = 0
        lastPacketHeader = []
        eventLog.append("hud:clear")
    }

    @discardableResult
    public func handleTouchpad(notifyIndex: Int, side: G1TouchpadSide) -> G1TouchpadAction {
        let action = touchpadRouter.route(
            notifyIndex: notifyIndex,
            side: side,
            hasActiveAnswer: hasActiveAnswer
        )
        lastTouchpadAction = action
        apply(action)
        eventLog.append("touch:\(action.displayTitle)")
        return action
    }

    private func apply(_ action: G1TouchpadAction) {
        switch action {
        case .previousPage:
            currentPageIndex = max(0, currentPageIndex - 1)
        case .nextPage:
            currentPageIndex = min(max(0, hudPages.count - 1), currentPageIndex + 1)
        case .exit:
            clearHud()
        default:
            break
        }
    }
}

public extension G1TouchpadAction {
    var displayTitle: String {
        switch self {
        case .exit: return "Exit"
        case .previousPage: return "Previous page"
        case .nextPage: return "Next page"
        case .headUp: return "Head up"
        case .headDown: return "Head down"
        case .evenAIStart: return "EvenAI start"
        case .evenAIRecordOver: return "EvenAI record over"
        case .unknown(let value): return "Unknown \(value)"
        }
    }
}
