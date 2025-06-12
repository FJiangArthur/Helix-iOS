import Foundation
import Combine
import Helix_Core_Transcription

/// ViewModel to drive ConversationView using TranscriptionCoordinator
@MainActor
class ConversationViewModel: ObservableObject {
    /// Published conversation messages
    @Published var messages: [ConversationMessage] = []
    /// Recording state
    @Published var isRecording: Bool = false
    /// Processing indicator
    @Published var isProcessing: Bool = false
    /// Error message
    @Published var errorMessage: String?

    private let transcriptionCoordinator: TranscriptionCoordinatorProtocol
    private var cancellables = Set<AnyCancellable>()

    init(transcriptionCoordinator: TranscriptionCoordinatorProtocol) {
        self.transcriptionCoordinator = transcriptionCoordinator
        setupBindings()
    }

    private func setupBindings() {
        transcriptionCoordinator.conversationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                }
            } receiveValue: { [weak self] update in
                guard let self = self else { return }
                self.messages.append(update.message)
                self.isProcessing = false
            }
            .store(in: &cancellables)
    }

    /// Start transcription
    func start() {
        guard !isRecording else { return }
        messages.removeAll()
        isRecording = true
        isProcessing = true
        transcriptionCoordinator.startConversationTranscription()
    }

    /// Stop transcription
    func stop() {
        guard isRecording else { return }
        isRecording = false
        isProcessing = false
        transcriptionCoordinator.stopConversationTranscription()
    }
}