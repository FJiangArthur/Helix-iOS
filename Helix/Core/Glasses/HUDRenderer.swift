import Foundation
import Combine

protocol HUDRendererProtocol {
    func render(_ content: HUDContent) -> AnyPublisher<Void, RenderError>
    func updateContent(_ content: HUDContent, with animation: HUDAnimation?)
    func clearAll()
    func setPriority(_ priority: DisplayPriority, for contentId: String)
    func getActiveDisplays() -> [HUDContent]
    func setDisplayCapabilities(_ capabilities: DisplayCapabilities)
}

enum RenderError: Error {
    case contentTooLong
    case invalidPosition
    case displayFull
    case renderingFailed(String)
    case hardwareError
    case contextLost
    
    var localizedDescription: String {
        switch self {
        case .contentTooLong:
            return "Content exceeds maximum display length"
        case .invalidPosition:
            return "Invalid display position"
        case .displayFull:
            return "Display capacity exceeded"
        case .renderingFailed(let message):
            return "Rendering failed: \(message)"
        case .hardwareError:
            return "Hardware rendering error"
        case .contextLost:
            return "Rendering context lost"
        }
    }
}

class HUDRenderer: HUDRendererProtocol {
    private let glassesManager: GlassesManagerProtocol
    private var activeDisplays: [String: ActiveDisplay] = [:]
    private var displayCapabilities: DisplayCapabilities = .default
    private var renderingSettings: RenderingSettings = .default
    
    private let renderingQueue = DispatchQueue(label: "hud.rendering", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()
    
    private struct ActiveDisplay {
        let content: HUDContent
        let renderTime: Date
        let expirationTime: Date?
        var isVisible: Bool
        
        init(content: HUDContent) {
            self.content = content
            self.renderTime = Date()
            self.expirationTime = content.duration.map { Date().addingTimeInterval($0) }
            self.isVisible = true
        }
        
        var isExpired: Bool {
            guard let expirationTime = expirationTime else { return false }
            return Date() > expirationTime
        }
    }
    
    struct RenderingSettings {
        let maxTextLength: Int
        let wordWrapEnabled: Bool
        let autoScroll: Bool
        let fadeInDuration: TimeInterval
        let fadeOutDuration: TimeInterval
        let displayTimeout: TimeInterval
        
        static let `default` = RenderingSettings(
            maxTextLength: 280,
            wordWrapEnabled: true,
            autoScroll: true,
            fadeInDuration: 0.3,
            fadeOutDuration: 0.3,
            displayTimeout: 10.0
        )
    }
    
    init(glassesManager: GlassesManagerProtocol) {
        self.glassesManager = glassesManager
        
        setupSubscriptions()
        startExpirationTimer()
    }
    
    func render(_ content: HUDContent) -> AnyPublisher<Void, RenderError> {
        return Future<Void, RenderError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.contextLost))
                return
            }
            
            self.renderingQueue.async {
                do {
                    try self.validateContent(content)
                    let processedContent = self.processContent(content)
                    
                    // Check if we can display more content
                    if self.activeDisplays.count >= self.displayCapabilities.maxConcurrentDisplays {
                        self.handleDisplayOverflow(for: processedContent)
                    }
                    
                    // Add to active displays
                    let activeDisplay = ActiveDisplay(content: processedContent)
                    self.activeDisplays[processedContent.id] = activeDisplay
                    
                    // Send to glasses
                    self.glassesManager.displayContent(processedContent)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    promise(.failure(.renderingFailed(error.localizedDescription)))
                                } else {
                                    promise(.success(()))
                                }
                            },
                            receiveValue: { _ in }
                        )
                        .store(in: &self.cancellables)
                        
                } catch {
                    promise(.failure(error as? RenderError ?? .renderingFailed(error.localizedDescription)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateContent(_ content: HUDContent, with animation: HUDAnimation? = nil) {
        renderingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Update existing content
            if var activeDisplay = self.activeDisplays[content.id] {
                let updatedContent = HUDContent(
                    id: content.id,
                    text: content.text,
                    style: content.style,
                    position: content.position,
                    duration: content.duration,
                    priority: content.priority,
                    animation: animation
                )
                
                activeDisplay = ActiveDisplay(content: updatedContent)
                self.activeDisplays[content.id] = activeDisplay
                
                self.glassesManager.displayContent(updatedContent)
                    .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                    .store(in: &self.cancellables)
            } else {
                // Render as new content
                self.render(content)
                    .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                    .store(in: &self.cancellables)
            }
        }
    }
    
    func clearAll() {
        renderingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.activeDisplays.removeAll()
            self.glassesManager.clearDisplay()
        }
    }
    
    func setPriority(_ priority: DisplayPriority, for contentId: String) {
        renderingQueue.async { [weak self] in
            guard let self = self,
                  var activeDisplay = self.activeDisplays[contentId] else { return }
            
            // Update priority
            let updatedContent = HUDContent(
                id: activeDisplay.content.id,
                text: activeDisplay.content.text,
                style: activeDisplay.content.style,
                position: activeDisplay.content.position,
                duration: activeDisplay.content.duration,
                priority: priority,
                animation: activeDisplay.content.animation
            )
            
            activeDisplay = ActiveDisplay(content: updatedContent)
            self.activeDisplays[contentId] = activeDisplay
            
            // Re-evaluate display order
            self.reevaluateDisplayOrder()
        }
    }
    
    func getActiveDisplays() -> [HUDContent] {
        return renderingQueue.sync {
            return activeDisplays.values.map { $0.content }
        }
    }
    
    func setDisplayCapabilities(_ capabilities: DisplayCapabilities) {
        renderingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.displayCapabilities = capabilities
            
            // Update rendering settings based on capabilities
            self.updateRenderingSettings(for: capabilities)
            
            // Re-evaluate current displays if we now have less capacity
            if self.activeDisplays.count > capabilities.maxConcurrentDisplays {
                self.enforceDisplayLimit()
            }
        }
    }
    
    private func setupSubscriptions() {
        glassesManager.displayCapabilities
            .sink { [weak self] capabilities in
                self?.setDisplayCapabilities(capabilities)
            }
            .store(in: &cancellables)
    }
    
    private func startExpirationTimer() {
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupExpiredDisplays()
            }
            .store(in: &cancellables)
    }
    
    private func validateContent(_ content: HUDContent) throws {
        // Validate text length
        if content.text.count > displayCapabilities.maxTextLength {
            throw RenderError.contentTooLong
        }
        
        // Validate position
        if content.position.x < 0 || content.position.x > 1 ||
           content.position.y < 0 || content.position.y > 1 {
            throw RenderError.invalidPosition
        }
        
        // Check if position is supported
        let isPositionSupported = displayCapabilities.supportedPositions.contains { supportedPos in
            abs(supportedPos.x - content.position.x) < 0.1 &&
            abs(supportedPos.y - content.position.y) < 0.1
        }
        
        if !isPositionSupported && !displayCapabilities.supportedPositions.isEmpty {
            throw RenderError.invalidPosition
        }
    }
    
    private func processContent(_ content: HUDContent) -> HUDContent {
        var processedText = content.text
        
        // Apply word wrapping if needed
        if renderingSettings.wordWrapEnabled {
            processedText = applyWordWrapping(to: processedText)
        }
        
        // Truncate if still too long
        if processedText.count > renderingSettings.maxTextLength {
            let endIndex = processedText.index(processedText.startIndex, offsetBy: renderingSettings.maxTextLength - 3)
            processedText = String(processedText[..<endIndex]) + "..."
        }
        
        // Apply auto-scroll formatting if needed
        if renderingSettings.autoScroll && processedText.count > 50 {
            processedText = formatForAutoScroll(processedText)
        }
        
        return HUDContent(
            id: content.id,
            text: processedText,
            style: content.style,
            position: optimizePosition(content.position),
            duration: content.duration ?? renderingSettings.displayTimeout,
            priority: content.priority,
            animation: content.animation ?? defaultAnimation(for: content.priority)
        )
    }
    
    private func applyWordWrapping(to text: String) -> String {
        let maxLineLength = 40 // Characters per line for glasses display
        let words = text.components(separatedBy: .whitespaces)
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            if currentLine.isEmpty {
                currentLine = word
            } else if (currentLine.count + word.count + 1) <= maxLineLength {
                currentLine += " " + word
            } else {
                lines.append(currentLine)
                currentLine = word
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func formatForAutoScroll(_ text: String) -> String {
        // Add markers for auto-scrolling
        return "🔄 " + text
    }
    
    private func optimizePosition(_ position: HUDPosition) -> HUDPosition {
        // Find the closest supported position
        guard !displayCapabilities.supportedPositions.isEmpty else { return position }
        
        let closestPosition = displayCapabilities.supportedPositions.min { pos1, pos2 in
            let distance1 = sqrt(pow(pos1.x - position.x, 2) + pow(pos1.y - position.y, 2))
            let distance2 = sqrt(pow(pos2.x - position.x, 2) + pow(pos2.y - position.y, 2))
            return distance1 < distance2
        }
        
        return closestPosition ?? position
    }
    
    private func defaultAnimation(for priority: DisplayPriority) -> HUDAnimation? {
        switch priority {
        case .critical:
            return HUDAnimation(type: .scale(from: 0.8, to: 1.0), duration: 0.4, easing: .easeOut)
        case .high:
            return .slideInFromTop
        case .medium:
            return .fadeIn
        case .low:
            return nil
        }
    }
    
    private func handleDisplayOverflow(for content: HUDContent) {
        // Find the lowest priority display that's not critical
        let sortedDisplays = activeDisplays.values.sorted { display1, display2 in
            if display1.content.priority.rawValue != display2.content.priority.rawValue {
                return display1.content.priority.rawValue < display2.content.priority.rawValue
            }
            return display1.renderTime < display2.renderTime // Older first
        }
        
        // Remove lowest priority display if the new content has higher priority
        if let lowestPriorityDisplay = sortedDisplays.first,
           lowestPriorityDisplay.content.priority.rawValue < content.priority.rawValue {
            
            removeDisplay(lowestPriorityDisplay.content.id)
        }
    }
    
    private func enforceDisplayLimit() {
        let maxDisplays = displayCapabilities.maxConcurrentDisplays
        let excessCount = activeDisplays.count - maxDisplays
        
        guard excessCount > 0 else { return }
        
        // Sort by priority (lowest first) and age (oldest first)
        let sortedDisplays = activeDisplays.values.sorted { display1, display2 in
            if display1.content.priority.rawValue != display2.content.priority.rawValue {
                return display1.content.priority.rawValue < display2.content.priority.rawValue
            }
            return display1.renderTime < display2.renderTime
        }
        
        // Remove excess displays
        for i in 0..<excessCount {
            let displayToRemove = sortedDisplays[i]
            removeDisplay(displayToRemove.content.id)
        }
    }
    
    private func reevaluateDisplayOrder() {
        // Get current displays sorted by priority
        let sortedDisplays = activeDisplays.values.sorted { display1, display2 in
            if display1.content.priority.rawValue != display2.content.priority.rawValue {
                return display1.content.priority.rawValue > display2.content.priority.rawValue
            }
            return display1.renderTime > display2.renderTime
        }
        
        // Keep only the highest priority displays within capacity
        let maxDisplays = displayCapabilities.maxConcurrentDisplays
        
        for (index, display) in sortedDisplays.enumerated() {
            if index >= maxDisplays {
                removeDisplay(display.content.id)
            }
        }
    }
    
    private func removeDisplay(_ id: String) {
        activeDisplays.removeValue(forKey: id)
        
        // Send clear command to glasses
        glassesManager.displayContent(HUDContent(id: id, text: "", style: HUDStyle(), position: .topCenter))
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    private func cleanupExpiredDisplays() {
        renderingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            var expiredIds: [String] = []
            
            for (id, activeDisplay) in self.activeDisplays {
                if activeDisplay.isExpired {
                    expiredIds.append(id)
                }
            }
            
            for id in expiredIds {
                self.removeDisplay(id)
            }
        }
    }
    
    private func updateRenderingSettings(for capabilities: DisplayCapabilities) {
        renderingSettings = RenderingSettings(
            maxTextLength: capabilities.maxTextLength,
            wordWrapEnabled: capabilities.resolution.width < 800,
            autoScroll: capabilities.resolution.width < 600,
            fadeInDuration: 0.3,
            fadeOutDuration: 0.3,
            displayTimeout: 10.0
        )
    }
}

// MARK: - HUD Content Factory

class HUDContentFactory {
    static func createFactCheckDisplay(_ result: FactCheckResult) -> HUDContent {
        let text = result.isAccurate ? 
            "✓ Confirmed" : 
            "✗ \(result.explanation)"
        
        let style = result.isAccurate ? 
            HUDStyle(color: .green, fontSize: .medium, isBold: true) :
            HUDStyle(color: .red, fontSize: .medium, isBold: true)
        
        return HUDContent(
            text: text,
            style: style,
            position: .topCenter,
            duration: result.isAccurate ? 3.0 : 8.0,
            priority: result.severity == .critical ? .critical : .high,
            animation: .slideInFromTop
        )
    }
    
    static func createSummaryDisplay(_ summary: String) -> HUDContent {
        return HUDContent(
            text: "📝 " + summary,
            style: .summary,
            position: .bottomCenter,
            duration: 6.0,
            priority: .medium,
            animation: .fadeIn
        )
    }
    
    static func createActionItemDisplay(_ actionItem: ActionItem) -> HUDContent {
        let priorityIcon = actionItem.priority == .urgent ? "🚨" : "📋"
        let text = "\(priorityIcon) \(actionItem.description)"
        
        return HUDContent(
            text: text,
            style: .actionItem,
            position: .topRight,
            duration: actionItem.priority.displayDuration,
            priority: mapActionItemPriority(actionItem.priority),
            animation: .slideInFromTop
        )
    }
    
    static func createNotificationDisplay(_ message: String, priority: DisplayPriority = .medium) -> HUDContent {
        return HUDContent(
            text: "💬 " + message,
            style: .notification,
            position: .topLeft,
            duration: priority.displayDuration,
            priority: priority,
            animation: .fadeIn
        )
    }
    
    private static func mapActionItemPriority(_ priority: ActionItemPriority) -> DisplayPriority {
        switch priority {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .urgent: return .critical
        }
    }
}

// MARK: - Display Position Helper

extension HUDPosition {
    static func dynamicPosition(avoiding conflicts: [HUDContent]) -> HUDPosition {
        let availablePositions: [HUDPosition] = [
            .topCenter, .topLeft, .topRight,
            .bottomCenter, 
            HUDPosition(x: 0.3, y: 0.5, alignment: .left, fontSize: .small),
            HUDPosition(x: 0.7, y: 0.5, alignment: .right, fontSize: .small)
        ]
        
        // Find position that doesn't conflict with existing content
        for position in availablePositions {
            let hasConflict = conflicts.contains { content in
                abs(content.position.x - position.x) < 0.2 &&
                abs(content.position.y - position.y) < 0.2
            }
            
            if !hasConflict {
                return position
            }
        }
        
        // Default to top center if all positions are occupied
        return .topCenter
    }
}