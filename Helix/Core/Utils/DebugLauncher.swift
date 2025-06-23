import Foundation
import SwiftUI
import Combine

// MARK: - Debug Launcher for Service Isolation Testing


struct DebugConfiguration {
    let enableAudio: Bool
    let enableSpeech: Bool
    let enableBluetooth: Bool
    let enableAI: Bool
    let enableDebugLogging: Bool
    let testMode: DebugTestMode
    
    static let allDisabled = DebugConfiguration(
        enableAudio: false,
        enableSpeech: false,
        enableBluetooth: false,
        enableAI: false,
        enableDebugLogging: true,
        testMode: .minimal
    )
    
    static let audioOnly = DebugConfiguration(
        enableAudio: true,
        enableSpeech: false,
        enableBluetooth: false,
        enableAI: false,
        enableDebugLogging: true,
        testMode: .audioTesting
    )
    
    static let speechOnly = DebugConfiguration(
        enableAudio: false,
        enableSpeech: true,
        enableBluetooth: false,
        enableAI: false,
        enableDebugLogging: true,
        testMode: .speechTesting
    )
    
    static let bluetoothOnly = DebugConfiguration(
        enableAudio: false,
        enableSpeech: false,
        enableBluetooth: true,
        enableAI: false,
        enableDebugLogging: true,
        testMode: .bluetoothTesting
    )
    
    static let aiOnly = DebugConfiguration(
        enableAudio: false,
        enableSpeech: false,
        enableBluetooth: false,
        enableAI: true,
        enableDebugLogging: true,
        testMode: .aiTesting
    )
    
    static let incremental1 = DebugConfiguration(
        enableAudio: true,
        enableSpeech: true,
        enableBluetooth: false,
        enableAI: false,
        enableDebugLogging: true,
        testMode: .incremental
    )
    
    static let incremental2 = DebugConfiguration(
        enableAudio: true,
        enableSpeech: true,
        enableBluetooth: true,
        enableAI: false,
        enableDebugLogging: true,
        testMode: .incremental
    )
    
    static let allEnabled = DebugConfiguration(
        enableAudio: true,
        enableSpeech: true,
        enableBluetooth: true,
        enableAI: true,
        enableDebugLogging: true,
        testMode: .full
    )
}

// Allow SwiftUI views like `.fullScreenCover(item:)` to present a configuration
// directly.  The `id` is derived from the combination of configuration fields
// so that two configurations with identical settings are considered the same
// value from the point-of-view of SwiftUI identity semantics.
extension DebugConfiguration: Identifiable {
    public var id: String {
        "\(enableAudio)-\(enableSpeech)-\(enableBluetooth)-\(enableAI)-\(testMode.rawValue)"
    }
}

enum DebugTestMode: String, CaseIterable {
    case minimal = "Minimal UI Only"
    case audioTesting = "Audio Service Testing"
    case speechTesting = "Speech Recognition Testing"
    case bluetoothTesting = "Bluetooth/Glasses Testing"
    case aiTesting = "AI Service Testing"
    case incremental = "Incremental Service Testing"
    case full = "Full System Testing"
    
    var description: String {
        switch self {
        case .minimal:
            return "Tests basic UI rendering with all services disabled"
        case .audioTesting:
            return "Tests audio capture and processing only"
        case .speechTesting:
            return "Tests speech recognition only"
        case .bluetoothTesting:
            return "Tests glasses connectivity only"
        case .aiTesting:
            return "Tests AI analysis services only"
        case .incremental:
            return "Tests services in combination"
        case .full:
            return "Tests all services together"
        }
    }
}

// MARK: - Debug Logger

class DebugLogger: ObservableObject {
    @Published var logs: [DebugLogEntry] = []
    private let maxLogs = 1000
    
    struct DebugLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let source: String
        let message: String
        
        enum LogLevel: String, CaseIterable {
            case debug = "DEBUG"
            case info = "INFO"
            case warning = "WARN"
            case error = "ERROR"
            case critical = "CRIT"
            
            var emoji: String {
                switch self {
                case .debug: return "🔍"
                case .info: return "ℹ️"
                case .warning: return "⚠️"
                case .error: return "❌"
                case .critical: return "🚨"
                }
            }
            
            var color: Color {
                switch self {
                case .debug: return .secondary
                case .info: return .blue
                case .warning: return .orange
                case .error: return .red
                case .critical: return .purple
                }
            }
        }
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }
    
    func log(_ level: DebugLogEntry.LogLevel, source: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let entry = DebugLogEntry(
                timestamp: Date(),
                level: level,
                source: source,
                message: message
            )
            
            self.logs.append(entry)
            
            // Maintain log size limit
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
            
            // Print to console as well
            print("[\(entry.formattedTimestamp)] \(level.emoji) \(source): \(message)")
        }
    }
    
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
        }
    }
}

// Global debug logger instance
let debugLogger = DebugLogger()

// MARK: - Debug Launch Helper

@MainActor
class DebugLauncher {
    /// Factory that produces an `AppCoordinator` while ensuring the call
    /// happens on the main actor (required because `AppCoordinator` itself
    /// is `@MainActor`).  If this method is invoked from a background
    /// thread/actor the Swift runtime will hop automatically.
    static func createAppCoordinator(with config: DebugConfiguration) -> AppCoordinator {
        if config.enableDebugLogging {
            debugLogger.log(.info, source: "DebugLauncher", message: "Starting app with configuration: \(config.testMode.rawValue)")
            debugLogger.log(.debug, source: "DebugLauncher", message: "Audio: \(config.enableAudio), Speech: \(config.enableSpeech), Bluetooth: \(config.enableBluetooth), AI: \(config.enableAI)")
        }
        
        return AppCoordinator(
            enableAudio: config.enableAudio,
            enableSpeech: config.enableSpeech,
            enableBluetooth: config.enableBluetooth,
            enableAI: config.enableAI
        )
    }
    
    static func getCurrentConfiguration() -> DebugConfiguration {
        // Check if we're in debug mode via environment or app settings
        if ProcessInfo.processInfo.environment["DEBUG_MODE"] != nil {
            return parseDebugConfiguration()
        }
        
        // Default to all enabled for release builds
        return .allEnabled
    }
    
    private static func parseDebugConfiguration() -> DebugConfiguration {
        let env = ProcessInfo.processInfo.environment
        
        return DebugConfiguration(
            enableAudio: env["DEBUG_AUDIO"] != "false",
            enableSpeech: env["DEBUG_SPEECH"] != "false", 
            enableBluetooth: env["DEBUG_BLUETOOTH"] != "false",
            enableAI: env["DEBUG_AI"] != "false",
            enableDebugLogging: env["DEBUG_LOGGING"] != "false",
            testMode: .full
        )
    }
}

// MARK: - Debug Configuration View

struct DebugConfigurationView: View {
    @State private var selectedConfig: DebugConfiguration = .allEnabled
    @State private var showingLogs = false
    @StateObject private var logger = debugLogger

    /// Callback fired when user taps the “Launch” button.
    /// The selected configuration is propagated so that the caller can
    /// instantiate an `AppCoordinator` with the right feature flags and swap
    /// it into the live environment.
    var onLaunch: (DebugConfiguration) -> Void = { _ in }

    private let configurations: [(String, DebugConfiguration)] = [
        ("Minimal (All Disabled)", .allDisabled),
        ("Audio Only", .audioOnly),
        ("Speech Only", .speechOnly),
        ("Bluetooth Only", .bluetoothOnly),
        ("AI Only", .aiOnly),
        ("Audio + Speech", .incremental1),
        ("Audio + Speech + Bluetooth", .incremental2),
        ("All Enabled", .allEnabled)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Debug Test Harness")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Select a configuration to test specific services")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(configurations, id: \.0) { name, config in
                        ConfigurationCard(
                            name: name,
                            config: config,
                            isSelected: selectedConfig.testMode == config.testMode
                        ) {
                            selectedConfig = config
                        }
                    }
                }

                Spacer()

                VStack(spacing: 16) {
                    Button("Launch with Selected Configuration") {
                        launchApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.headline)

                    Button("View Debug Logs") {
                        showingLogs = true
                    }
                    .buttonStyle(.bordered)

                    if !logger.logs.isEmpty {
                        Text("\(logger.logs.count) log entries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingLogs) {
            DebugLogsView()
        }
    }

    private func launchApp() {
        debugLogger.log(.info, source: "DebugUI", message: "Launching app with \(selectedConfig.testMode.rawValue)")

        onLaunch(selectedConfig)
    }
}

struct ConfigurationCard: View {
    let name: String
    let config: DebugConfiguration
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.headline)
                .lineLimit(2)
            
            Text(config.testMode.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                ServiceIndicator(name: "Audio", enabled: config.enableAudio)
                ServiceIndicator(name: "Speech", enabled: config.enableSpeech)
                ServiceIndicator(name: "BT", enabled: config.enableBluetooth)
                ServiceIndicator(name: "AI", enabled: config.enableAI)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct ServiceIndicator: View {
    let name: String
    let enabled: Bool
    
    var body: some View {
        Text(name)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(enabled ? .white : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(enabled ? Color.green : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary, lineWidth: enabled ? 0 : 1)
                    )
            )
    }
}

// MARK: - Debug Logs View

struct DebugLogsView: View {
    @StateObject private var logger = debugLogger
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(logger.logs.reversed()) { entry in
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.level.emoji)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.formattedTimestamp)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(entry.source)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(entry.level.color)
                        }
                        
                        Text(entry.message)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        logger.clear()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DebugConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        DebugConfigurationView()
    }
}
#endif