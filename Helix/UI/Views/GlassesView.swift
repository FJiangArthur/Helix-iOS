import SwiftUI

struct GlassesView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var showingTestDisplay = false
    @State private var testMessage = "Test message"
    
    var body: some View {
        NavigationView {
            List {
                ConnectionSection()
                
                if coordinator.isConnectedToGlasses {
                    StatusSection()
                    DisplayTestSection(
                        showingTestDisplay: $showingTestDisplay,
                        testMessage: $testMessage
                    )
                    DisplaySettingsSection()
                }
            }
            .navigationTitle("Glasses")
            .toolbar {
                if coordinator.isConnectedToGlasses {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Disconnect") {
                            coordinator.disconnectFromGlasses()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTestDisplay) {
            TestDisplaySheet(testMessage: $testMessage)
        }
    }
}

struct ConnectionSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        Section("Connection") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Even Realities Glasses")
                        .font(.headline)
                    
                    Text(coordinator.connectionState.statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ConnectionStatusIndicator(state: coordinator.connectionState)
            }
            .padding(.vertical, 8)
            
            if !coordinator.isConnectedToGlasses {
                Button("Connect to Glasses") {
                    coordinator.connectToGlasses()
                }
                .buttonStyle(.bordered)
                .disabled(coordinator.connectionState == .scanning || coordinator.connectionState == .connecting)
            }
        }
    }
}

struct ConnectionStatusIndicator: View {
    let state: ConnectionState
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.indicatorColor)
                .frame(width: 12, height: 12)
                .scaleEffect(state == .scanning || state == .connecting ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: state == .scanning || state == .connecting)
            
            Text(state.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(state.textColor)
        }
    }
}

struct StatusSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        Section("Status") {
            StatusRow(
                icon: "battery.100",
                title: "Battery Level",
                value: "\(Int(coordinator.batteryLevel * 100))%",
                color: batteryColor
            )
            
            StatusRow(
                icon: "eye",
                title: "Display Status",
                value: "Active",
                color: .green
            )
            
            StatusRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "Signal Strength",
                value: "Strong",
                color: .green
            )
        }
    }
    
    private var batteryColor: Color {
        switch coordinator.batteryLevel {
        case 0.5...1.0: return .green
        case 0.2..<0.5: return .orange
        default: return .red
        }
    }
}

struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct DisplayTestSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Binding var showingTestDisplay: Bool
    @Binding var testMessage: String
    
    var body: some View {
        Section("Display Test") {
            HStack {
                TextField("Test message", text: $testMessage)
                    .textFieldStyle(.roundedBorder)
                
                Button("Send") {
                    sendTestMessage()
                }
                .buttonStyle(.bordered)
                .disabled(testMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            Button("Advanced Test") {
                showingTestDisplay = true
            }
            .buttonStyle(.bordered)
            
            Button("Clear Display") {
                clearDisplay()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func sendTestMessage() {
        // TODO: Implement with actual HUD renderer
        print("Sending test message: \(testMessage)")
    }
    
    private func clearDisplay() {
        // TODO: Implement with actual HUD renderer
        print("Clearing display")
    }
}

struct DisplaySettingsSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var brightness: Double = 0.8
    @State private var autoAdjust = true
    
    var body: some View {
        Section("Display Settings") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Brightness")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "sun.min")
                        .foregroundColor(.secondary)
                    
                    Slider(value: $brightness, in: 0.1...1.0)
                        .onChange(of: brightness) { newValue in
                            updateBrightness(newValue)
                        }
                    
                    Image(systemName: "sun.max")
                        .foregroundColor(.secondary)
                }
            }
            
            Toggle("Auto-adjust brightness", isOn: $autoAdjust)
                .onChange(of: autoAdjust) { newValue in
                    updateAutoAdjust(newValue)
                }
        }
    }
    
    private func updateBrightness(_ value: Double) {
        // TODO: Implement with actual glasses manager
        print("Updated brightness to: \(value)")
    }
    
    private func updateAutoAdjust(_ enabled: Bool) {
        // TODO: Implement with actual glasses manager
        print("Auto-adjust brightness: \(enabled)")
    }
}

struct TestDisplaySheet: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @Binding var testMessage: String
    
    @State private var selectedPosition: HUDPosition = .topCenter
    @State private var selectedColor: HUDColor = .white
    @State private var selectedSize: FontSize = .medium
    @State private var duration: Double = 5.0
    @State private var isBold = false
    
    private let positions: [HUDPosition] = [
        .topLeft, .topCenter, .topRight,
        HUDPosition(x: 0.5, y: 0.5, alignment: .center, fontSize: .medium),
        HUDPosition(x: 0.1, y: 0.9, alignment: .left, fontSize: .small),
        HUDPosition(x: 0.9, y: 0.9, alignment: .right, fontSize: .small)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Message") {
                    TextField("Test message", text: $testMessage)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Position") {
                    Picker("Position", selection: $selectedPosition) {
                        ForEach(positions, id: \.description) { position in
                            Text(position.displayName)
                                .tag(position)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section("Style") {
                    Picker("Color", selection: $selectedColor) {
                        ForEach(HUDColor.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(Color(color))
                                    .frame(width: 16, height: 16)
                                
                                Text(color.rawValue.capitalized)
                            }
                            .tag(color)
                        }
                    }
                    
                    Picker("Size", selection: $selectedSize) {
                        ForEach(FontSize.allCases, id: \.self) { size in
                            Text(size.rawValue.capitalized)
                                .tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Bold", isOn: $isBold)
                }
                
                Section("Duration") {
                    HStack {
                        Text("Duration: \(Int(duration))s")
                        Spacer()
                        Slider(value: $duration, in: 1...30, step: 1)
                    }
                }
                
                Section {
                    Button("Send Test Display") {
                        sendTestDisplay()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(testMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Test Display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendTestDisplay() {
        // TODO: Implement with actual HUD renderer
        print("Sending test display with settings:")
        print("Message: \(testMessage)")
        print("Position: \(selectedPosition.displayName)")
        print("Color: \(selectedColor.rawValue)")
        print("Size: \(selectedSize.rawValue)")
        print("Duration: \(duration)")
        print("Bold: \(isBold)")
        
        dismiss()
    }
}

// MARK: - Extensions

extension ConnectionState {
    var statusDescription: String {
        switch self {
        case .disconnected:
            return "Not connected"
        case .scanning:
            return "Scanning for devices..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected and ready"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
    
    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .scanning:
            return "Scanning"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .error:
            return "Error"
        }
    }
    
    var indicatorColor: Color {
        switch self {
        case .disconnected:
            return .gray
        case .scanning, .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
    
    var textColor: Color {
        switch self {
        case .error:
            return .red
        case .connected:
            return .green
        case .scanning, .connecting:
            return .orange
        default:
            return .secondary
        }
    }
}

extension HUDPosition: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(alignment)
        hasher.combine(fontSize)
    }
    
    static func == (lhs: HUDPosition, rhs: HUDPosition) -> Bool {
        return lhs.x == rhs.x &&
               lhs.y == rhs.y &&
               lhs.alignment == rhs.alignment &&
               lhs.fontSize == rhs.fontSize
    }
}

extension Color {
    init(_ hudColor: HUDColor) {
        let rgb = hudColor.rgbValues
        self.init(red: Double(rgb.r), green: Double(rgb.g), blue: Double(rgb.b))
    }
}

#Preview {
    GlassesView()
        .environmentObject(AppCoordinator())
}