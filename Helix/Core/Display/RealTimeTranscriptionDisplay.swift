//
//  RealTimeTranscriptionDisplay.swift
//  Helix
//

import Foundation
import SwiftUI
import Combine

// MARK: - Transcription Display Configuration

struct TranscriptionDisplaySettings {
    var textSize: TextSize
    var textColor: Color
    var backgroundColor: Color
    var fontFamily: FontFamily
    var displayMode: DisplayMode
    var position: DisplayPosition
    var scrollBehavior: ScrollBehavior
    var fadeInAnimation: Bool
    var wordHighlighting: Bool
    var speakerColors: [UUID: Color]
    var maxVisibleLines: Int
    var autoHideDelay: TimeInterval
    var confidence: ConfidenceDisplay
    
    static let `default` = TranscriptionDisplaySettings(
        textSize: .medium,
        textColor: .primary,
        backgroundColor: .clear,
        fontFamily: .system,
        displayMode: .overlay,
        position: .bottom,
        scrollBehavior: .smooth,
        fadeInAnimation: true,
        wordHighlighting: true,
        speakerColors: [:],
        maxVisibleLines: 3,
        autoHideDelay: 5.0,
        confidence: .minimal
    )
    
    static let glassesOptimized = TranscriptionDisplaySettings(
        textSize: .large,
        textColor: .white,
        backgroundColor: Color.black.opacity(0.3),
        fontFamily: .monospace,
        displayMode: .overlay,
        position: .center,
        scrollBehavior: .snap,
        fadeInAnimation: true,
        wordHighlighting: false,
        speakerColors: [:],
        maxVisibleLines: 2,
        autoHideDelay: 3.0,
        confidence: .none
    )
}

enum TextSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extra_large"
    
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.5
        }
    }
}

enum FontFamily: String, CaseIterable, Codable {
    case system = "system"
    case monospace = "monospace"
    case serif = "serif"
    case sansSerif = "sans_serif"
    
    var font: Font {
        switch self {
        case .system: return .system(.body)
        case .monospace: return .system(.body, design: .monospaced)
        case .serif: return .system(.body, design: .serif)
        case .sansSerif: return .system(.body, design: .default)
        }
    }
}

enum DisplayMode: String, CaseIterable, Codable {
    case overlay = "overlay"
    case sidebar = "sidebar"
    case popup = "popup"
    case floating = "floating"
    case fullscreen = "fullscreen"
    
    var description: String {
        switch self {
        case .overlay: return "Overlay on screen"
        case .sidebar: return "Side panel"
        case .popup: return "Popup window"
        case .floating: return "Floating window"
        case .fullscreen: return "Full screen"
        }
    }
}

enum DisplayPosition: String, CaseIterable, Codable {
    case top = "top"
    case center = "center"
    case bottom = "bottom"
    case left = "left"
    case right = "right"
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"
}

enum ScrollBehavior: String, CaseIterable, Codable {
    case smooth = "smooth"
    case snap = "snap"
    case instant = "instant"
    case typewriter = "typewriter"
}

enum ConfidenceDisplay: String, CaseIterable, Codable {
    case none = "none"
    case minimal = "minimal"
    case detailed = "detailed"
    case color_coded = "color_coded"
}

// MARK: - Transcription Display Item

struct TranscriptionDisplayItem: Identifiable, Hashable {
    let id: UUID
    let text: String
    let speakerId: UUID?
    let speakerName: String
    let timestamp: TimeInterval
    let confidence: Float
    let isFinal: Bool
    let wordTimings: [WordTiming]
    let isCurrentSpeaker: Bool
    
    init(from message: ConversationMessage, speakerName: String = "Unknown", isCurrentSpeaker: Bool = false) {
        self.id = UUID()
        self.text = message.content
        self.speakerId = message.speakerId
        self.speakerName = speakerName
        self.timestamp = message.timestamp
        self.confidence = message.confidence
        self.isFinal = message.isFinal
        self.wordTimings = message.wordTimings
        self.isCurrentSpeaker = isCurrentSpeaker
    }
}

// MARK: - Real-Time Transcription Display

protocol RealTimeTranscriptionDisplayProtocol {
    var displayItems: AnyPublisher<[TranscriptionDisplayItem], Never> { get }
    var settings: AnyPublisher<TranscriptionDisplaySettings, Never> { get }
    var isVisible: AnyPublisher<Bool, Never> { get }
    
    func updateSettings(_ newSettings: TranscriptionDisplaySettings)
    func addTranscriptionItem(_ item: TranscriptionDisplayItem)
    func updateTranscriptionItem(_ item: TranscriptionDisplayItem)
    func clearDisplay()
    func show()
    func hide()
    func toggleVisibility()
}

class RealTimeTranscriptionDisplay: RealTimeTranscriptionDisplayProtocol, ObservableObject {
    private let displayItemsSubject = CurrentValueSubject<[TranscriptionDisplayItem], Never>([])
    private let settingsSubject = CurrentValueSubject<TranscriptionDisplaySettings, Never>(.default)
    private let isVisibleSubject = CurrentValueSubject<Bool, Never>(true)
    
    private var autoHideTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    var displayItems: AnyPublisher<[TranscriptionDisplayItem], Never> {
        displayItemsSubject.eraseToAnyPublisher()
    }
    
    var settings: AnyPublisher<TranscriptionDisplaySettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }
    
    var isVisible: AnyPublisher<Bool, Never> {
        isVisibleSubject.eraseToAnyPublisher()
    }
    
    init() {
        setupAutoHide()
    }
    
    func updateSettings(_ newSettings: TranscriptionDisplaySettings) {
        settingsSubject.send(newSettings)
        setupAutoHide()
    }
    
    func addTranscriptionItem(_ item: TranscriptionDisplayItem) {
        var items = displayItemsSubject.value
        items.append(item)
        
        // Limit the number of visible items
        let maxItems = settingsSubject.value.maxVisibleLines
        if items.count > maxItems {
            items = Array(items.suffix(maxItems))
        }
        
        displayItemsSubject.send(items)
        resetAutoHideTimer()
        
        if !isVisibleSubject.value {
            show()
        }
    }
    
    func updateTranscriptionItem(_ item: TranscriptionDisplayItem) {
        var items = displayItemsSubject.value
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            // If item doesn't exist, add it
            items.append(item)
        }
        
        displayItemsSubject.send(items)
        resetAutoHideTimer()
    }
    
    func clearDisplay() {
        displayItemsSubject.send([])
        hide()
    }
    
    func show() {
        isVisibleSubject.send(true)
        resetAutoHideTimer()
    }
    
    func hide() {
        isVisibleSubject.send(false)
        autoHideTimer?.invalidate()
    }
    
    func toggleVisibility() {
        if isVisibleSubject.value {
            hide()
        } else {
            show()
        }
    }
    
    private func setupAutoHide() {
        let settings = settingsSubject.value
        if settings.autoHideDelay > 0 {
            resetAutoHideTimer()
        }
    }
    
    private func resetAutoHideTimer() {
        autoHideTimer?.invalidate()
        
        let settings = settingsSubject.value
        guard settings.autoHideDelay > 0 else { return }
        
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: settings.autoHideDelay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
}

// MARK: - SwiftUI Views

struct TranscriptionDisplayView: View {
    @ObservedObject private var display: RealTimeTranscriptionDisplay
    @State private var settings: TranscriptionDisplaySettings
    @State private var items: [TranscriptionDisplayItem] = []
    @State private var isVisible: Bool = true
    
    init(display: RealTimeTranscriptionDisplay) {
        self.display = display
        self._settings = State(initialValue: .default)
    }
    
    var body: some View {
        Group {
            if isVisible && !items.isEmpty {
                content
                    .opacity(isVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: isVisible)
            }
        }
        .onReceive(display.displayItems) { newItems in
            withAnimation(settings.fadeInAnimation ? .easeInOut(duration: 0.2) : .none) {
                items = newItems
            }
        }
        .onReceive(display.settings) { newSettings in
            settings = newSettings
        }
        .onReceive(display.isVisible) { visible in
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = visible
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch settings.displayMode {
        case .overlay:
            overlayContent
        case .sidebar:
            sidebarContent
        case .popup:
            popupContent
        case .floating:
            floatingContent
        case .fullscreen:
            fullscreenContent
        }
    }
    
    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                TranscriptionItemView(item: item, settings: settings)
            }
        }
        .padding()
        .background(settings.backgroundColor)
        .cornerRadius(8)
        .position(for: settings.position)
    }
    
    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Transcription")
                .font(.headline)
                .foregroundColor(settings.textColor)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        TranscriptionItemView(item: item, settings: settings)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .frame(width: 300)
        .background(settings.backgroundColor)
    }
    
    private var popupContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                TranscriptionItemView(item: item, settings: settings)
            }
        }
        .padding()
        .background(settings.backgroundColor)
        .cornerRadius(12)
        .shadow(radius: 10)
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .animation(.spring(), value: isVisible)
    }
    
    private var floatingContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                TranscriptionItemView(item: item, settings: settings)
            }
        }
        .padding()
        .background(settings.backgroundColor)
        .cornerRadius(8)
        .shadow(radius: 5)
        .gesture(
            DragGesture()
                .onEnded { _ in
                    // Allow dragging to reposition
                }
        )
    }
    
    private var fullscreenContent: some View {
        VStack {
            Spacer()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        TranscriptionItemView(item: item, settings: settings)
                            .padding(.horizontal)
                    }
                }
            }
            .frame(maxHeight: 400)
            
            Spacer()
        }
        .background(settings.backgroundColor)
    }
}

struct TranscriptionItemView: View {
    let item: TranscriptionDisplayItem
    let settings: TranscriptionDisplaySettings
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Speaker indicator
            speakerIndicator
            
            // Transcription content
            VStack(alignment: .leading, spacing: 2) {
                // Speaker name and timestamp
                if !item.speakerName.isEmpty {
                    HStack {
                        Text(item.speakerName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(speakerColor)
                        
                        Spacer()
                        
                        if settings.confidence != .none {
                            confidenceIndicator
                        }
                    }
                }
                
                // Transcription text
                if settings.wordHighlighting && !item.wordTimings.isEmpty {
                    wordByWordText
                } else {
                    regularText
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: item.isFinal)
    }
    
    private var speakerIndicator: some View {
        Circle()
            .fill(speakerColor)
            .frame(width: 8, height: 8)
            .opacity(item.isCurrentSpeaker ? 1.0 : 0.6)
    }
    
    private var speakerColor: Color {
        if let speakerId = item.speakerId,
           let color = settings.speakerColors[speakerId] {
            return color
        }
        return item.isCurrentSpeaker ? .blue : .gray
    }
    
    private var confidenceIndicator: some View {
        Group {
            switch settings.confidence {
            case .minimal:
                if item.confidence < 0.7 {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
            case .detailed:
                Text("\(Int(item.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(confidenceColor)
                
            case .color_coded:
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 6, height: 6)
                
            case .none:
                EmptyView()
            }
        }
    }
    
    private var confidenceColor: Color {
        switch item.confidence {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .yellow
        case 0.5..<0.7: return .orange
        default: return .red
        }
    }
    
    private var regularText: some View {
        Text(item.text)
            .font(settings.fontFamily.font)
            .scaleEffect(settings.textSize.scaleFactor)
            .foregroundColor(settings.textColor)
            .opacity(item.isFinal ? 1.0 : 0.7)
            .animation(.easeInOut(duration: 0.3), value: item.isFinal)
    }
    
    private var wordByWordText: some View {
        // Placeholder for word-by-word highlighting
        // This would implement real-time word highlighting based on timing
        Text(item.text)
            .font(settings.fontFamily.font)
            .scaleEffect(settings.textSize.scaleFactor)
            .foregroundColor(settings.textColor)
            .opacity(item.isFinal ? 1.0 : 0.7)
    }
}

// MARK: - View Extensions

extension View {
    func position(for displayPosition: DisplayPosition) -> some View {
        switch displayPosition {
        case .top:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top))
        case .center:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center))
        case .bottom:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom))
        case .left:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading))
        case .right:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing))
        case .topLeft:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
        case .topRight:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing))
        case .bottomLeft:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading))
        case .bottomRight:
            return AnyView(self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing))
        }
    }
}

// MARK: - Glasses Display Integration

class GlassesTranscriptionRenderer {
    private let glassesManager: GlassesManagerProtocol
    private let display: RealTimeTranscriptionDisplay
    private var cancellables = Set<AnyCancellable>()
    
    init(glassesManager: GlassesManagerProtocol, display: RealTimeTranscriptionDisplay) {
        self.glassesManager = glassesManager
        self.display = display
        
        setupGlassesSync()
    }
    
    private func setupGlassesSync() {
        display.displayItems
            .combineLatest(display.settings)
            .sink { [weak self] (items, settings) in
                self?.renderOnGlasses(items: items, settings: settings)
            }
            .store(in: &cancellables)
    }
    
    private func renderOnGlasses(items: [TranscriptionDisplayItem], settings: TranscriptionDisplaySettings) {
        guard !items.isEmpty else { return }
        
        // Convert items to HUD content
        let latestItem = items.last!
        let text = formatForGlasses(item: latestItem, settings: settings)
        
        let hudContent = HUDContent(
            text: text,
            style: HUDStyle.transcription,
            position: mapToHUDPosition(settings.position),
            duration: settings.autoHideDelay,
            priority: .medium
        )
        
        glassesManager.displayContent(hudContent)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to display transcription on glasses: \(error)")
                    }
                },
                receiveValue: { _ in
                    // Successfully displayed
                }
            )
            .store(in: &cancellables)
    }
    
    private func formatForGlasses(item: TranscriptionDisplayItem, settings: TranscriptionDisplaySettings) -> String {
        var formattedText = ""
        
        // Add speaker name if enabled
        if !item.speakerName.isEmpty && settings.displayMode != .overlay {
            formattedText += "\(item.speakerName): "
        }
        
        formattedText += item.text
        
        // Truncate if too long for glasses display
        if formattedText.count > 60 {
            formattedText = String(formattedText.prefix(57)) + "..."
        }
        
        return formattedText
    }
    
    private func mapToHUDPosition(_ position: DisplayPosition) -> HUDPosition {
        switch position {
        case .top: return .topCenter
        case .center: return .topCenter
        case .bottom: return .bottomCenter
        case .left: return .topLeft
        case .right: return .topRight
        case .topLeft: return .topLeft
        case .topRight: return .topRight
        case .bottomLeft: return .topLeft
        case .bottomRight: return .topRight
        }
    }
}

// MARK: - HUD Style Extension

extension HUDStyle {
    /// Style for real-time transcription HUD
    static let transcription = HUDStyle(
        color: .white,
        backgroundColor: .black,
        fontSize: .medium,
        isBold: false,
        isItalic: false,
        opacity: 0.8
    )
}