import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var settings: AppSettings = .default
    @State private var showingAPIKeySheet = false
    @State private var showingAboutSheet = false
    
    var body: some View {
        NavigationView {
            Form {
                APIKeysSection(
                    settings: $settings,
                    showingAPIKeySheet: $showingAPIKeySheet
                )
                
                AudioSection(settings: $settings)
                
                AnalysisSection(settings: $settings)

                SpeechSection(settings: $settings)
                
                GlassesSection(settings: $settings)
                
                PrivacySection(settings: $settings)
                
                AboutSection(showingAboutSheet: $showingAboutSheet)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        resetSettings()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeySheet(settings: $settings)
        }
        .sheet(isPresented: $showingAboutSheet) {
            AboutSheet()
        }
        .onAppear {
            settings = coordinator.settings
        }
        .onChange(of: settings) { newSettings in
            coordinator.updateSettings(newSettings)
        }
    }
    
    private func resetSettings() {
        settings = .default
    }
}

struct APIKeysSection: View {
    @Binding var settings: AppSettings
    @Binding var showingAPIKeySheet: Bool
    
    var body: some View {
        Section("AI Services") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenAI API Key")
                        .font(.body)
                    
                    Text(settings.openAIKey.isEmpty ? "Not configured" : "Configured")
                        .font(.caption)
                        .foregroundColor(settings.openAIKey.isEmpty ? .red : .green)
                }
                
                Spacer()
                
                Button("Configure") {
                    showingAPIKeySheet = true
                }
                .buttonStyle(.bordered)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Anthropic API Key")
                        .font(.body)
                    
                    Text(settings.anthropicKey.isEmpty ? "Not configured" : "Configured")
                        .font(.caption)
                        .foregroundColor(settings.anthropicKey.isEmpty ? .red : .green)
                }
                
                Spacer()
                
                Button("Configure") {
                    showingAPIKeySheet = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct SpeechSection: View {
    @Binding var settings: AppSettings

    var body: some View {
        Section("Speech Backend") {
            Picker("Recognition Engine", selection: $settings.speechBackend) {
                ForEach(SpeechBackend.allCases, id: \.self) { backend in
                    Text(backend.description).tag(backend)
                }
            }
            .pickerStyle(.segmented)

            if settings.speechBackend != AppSettings.default.speechBackend {
                Text("Changing the speech backend will take effect on the next recording session.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if settings.speechBackend == .localDictation {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.blue)
                        Text("Uses iOS local dictation for offline speech recognition.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("• Works completely offline\n• Faster processing\n• Enhanced privacy")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
            
            if settings.speechBackend == .remoteWhisper {
                if settings.openAIKey.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("OpenAI API key required. Configure in AI Services section above.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.1))
                    .cornerRadius(6)
                } else {
                    HStack {
                        Text("Uses the OpenAI Whisper API to perform speech recognition, speaker identification, and diarization in the cloud.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct AudioSection: View {
    @Binding var settings: AppSettings
    
    var body: some View {
        Section("Audio Processing") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Sensitivity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Low")
                        .font(.caption)
                    
                    Slider(value: $settings.voiceSensitivity, in: 0.1...1.0)
                    
                    Text("High")
                        .font(.caption)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Noise Reduction")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Off")
                        .font(.caption)
                    
                    Slider(value: $settings.noiseReductionLevel, in: 0.0...1.0)
                    
                    Text("Max")
                        .font(.caption)
                }
            }
            
            Picker("Primary Language", selection: $settings.primaryLanguage) {
                Text("English (US)").tag(Locale(identifier: "en-US") as Locale?)
                Text("English (UK)").tag(Locale(identifier: "en-GB") as Locale?)
                Text("Spanish").tag(Locale(identifier: "es") as Locale?)
                Text("French").tag(Locale(identifier: "fr") as Locale?)
                Text("German").tag(Locale(identifier: "de") as Locale?)
            }
        }
    }
}

struct AnalysisSection: View {
    @Binding var settings: AppSettings
    
    var body: some View {
        Section("AI Analysis") {
            Toggle("Fact Checking", isOn: $settings.enableFactChecking)
            
            Toggle("Auto Summary", isOn: $settings.enableAutoSummary)
            
            Toggle("Action Items", isOn: $settings.enableActionItems)
            
            Picker("Fact-Check Sensitivity", selection: $settings.factCheckSeverityFilter) {
                Text("All Claims").tag(FactCheckResult.FactCheckSeverity.minor)
                Text("Significant Claims").tag(FactCheckResult.FactCheckSeverity.significant)
                Text("Critical Only").tag(FactCheckResult.FactCheckSeverity.critical)
            }
            
            HStack {
                Text("Max History")
                Spacer()
                Stepper("\(settings.maxConversationHistory) messages", 
                       value: $settings.maxConversationHistory, 
                       in: 50...500, 
                       step: 50)
            }
        }
    }
}

struct GlassesSection: View {
    @Binding var settings: AppSettings
    
    var body: some View {
        Section("Glasses Display") {
            Toggle("Auto-connect on startup", isOn: $settings.glassesAutoConnect)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Brightness")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "sun.min")
                        .foregroundColor(.secondary)
                    
                    Slider(value: $settings.displayBrightness, in: 0.1...1.0)
                    
                    Image(systemName: "sun.max")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct PrivacySection: View {
    @Binding var settings: AppSettings
    
    var body: some View {
        Section("Privacy & Data") {
            Toggle("Privacy Mode", isOn: $settings.privacyMode)
            
            Toggle("Auto Export", isOn: $settings.autoExport)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Data Storage")
                        .font(.body)
                    
                    Text("All data is stored locally on your device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Manage") {
                    // TODO: Implement data management
                }
                .buttonStyle(.bordered)
            }
            
            Button("Clear All Data") {
                clearAllData()
            }
            .foregroundColor(.red)
        }
    }
    
    private func clearAllData() {
        // TODO: Implement data clearing
        print("Clearing all data")
    }
}

struct AboutSection: View {
    @Binding var showingAboutSheet: Bool
    
    var body: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            Button("About Helix") {
                showingAboutSheet = true
            }
            
            Button("Privacy Policy") {
                openPrivacyPolicy()
            }
            
            Button("Terms of Service") {
                openTermsOfService()
            }
            
            Button("Support") {
                openSupport()
            }
        }
    }
    
    private func openPrivacyPolicy() {
        // TODO: Open privacy policy
        print("Opening privacy policy")
    }
    
    private func openTermsOfService() {
        // TODO: Open terms of service
        print("Opening terms of service")
    }
    
    private func openSupport() {
        // TODO: Open support
        print("Opening support")
    }
}

struct APIKeySheet: View {
    @Binding var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var showingOpenAIKey = false
    @State private var showingAnthropicKey = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("OpenAI") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if showingOpenAIKey {
                                TextField("sk-...", text: $openAIKey)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("sk-...", text: $openAIKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button(action: {
                                showingOpenAIKey.toggle()
                            }) {
                                Image(systemName: showingOpenAIKey ? "eye.slash" : "eye")
                            }
                        }
                        
                        Text("Get your API key from platform.openai.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Anthropic") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if showingAnthropicKey {
                                TextField("sk-ant-...", text: $anthropicKey)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("sk-ant-...", text: $anthropicKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button(action: {
                                showingAnthropicKey.toggle()
                            }) {
                                Image(systemName: showingAnthropicKey ? "eye.slash" : "eye")
                            }
                        }
                        
                        Text("Get your API key from console.anthropic.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Security Notice")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("API keys are stored securely in your device's keychain and are never transmitted except to the respective AI service providers.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAPIKeys()
                    }
                }
            }
        }
        .onAppear {
            openAIKey = settings.openAIKey
            anthropicKey = settings.anthropicKey
        }
    }
    
    private func saveAPIKeys() {
        settings.openAIKey = openAIKey
        settings.anthropicKey = anthropicKey
        dismiss()
    }
}

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Title
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 4) {
                            Text("Helix")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("AI-Powered Conversation Analysis")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About Helix")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Helix is an advanced conversation analysis tool that works with Even Realities smart glasses to provide real-time AI-powered insights, fact-checking, and conversation intelligence.")
                            .font(.body)
                        
                        Text("Features include:")
                            .font(.headline)
                            .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureBullet(text: "Real-time speech recognition and transcription")
                            FeatureBullet(text: "AI-powered fact-checking with source attribution")
                            FeatureBullet(text: "Automatic conversation summarization")
                            FeatureBullet(text: "Action item extraction and tracking")
                            FeatureBullet(text: "Speaker identification and diarization")
                            FeatureBullet(text: "Smart glasses HUD integration")
                            FeatureBullet(text: "Privacy-first data handling")
                        }
                    }
                    
                    // Technical Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Technical Information")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        TechnicalDetail(title: "Version", value: "1.0.0")
                        TechnicalDetail(title: "Build", value: "2025.01.01")
                        TechnicalDetail(title: "Platform", value: "iOS 16.0+")
                        TechnicalDetail(title: "AI Models", value: "OpenAI GPT-4, Anthropic DSonnet")
                        TechnicalDetail(title: "Audio Processing", value: "16kHz real-time pipeline")
                    }
                    
                    // Privacy Notice
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy & Security")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Helix prioritizes your privacy:")
                            .font(.body)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            PrivacyBullet(text: "All conversations are processed locally when possible")
                            PrivacyBullet(text: "Data is encrypted and stored securely on your device")
                            PrivacyBullet(text: "No conversation data is stored on our servers")
                            PrivacyBullet(text: "API keys are protected in the device keychain")
                            PrivacyBullet(text: "You control all data sharing and export")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.blue)
                .fontWeight(.bold)
            
            Text(text)
                .font(.body)
        }
    }
}

struct TechnicalDetail: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

struct PrivacyBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppCoordinator())
}