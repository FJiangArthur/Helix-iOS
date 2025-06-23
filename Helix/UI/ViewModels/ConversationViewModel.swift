import Foundation
import Combine

/// ViewModel for live conversation transcription
@MainActor
class ConversationViewModel: ObservableObject {
    @Published var messages: [ConversationMessage] = []
    @Published var isRecording: Bool = false
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var liveTranscription: String?

    private let transcriptionCoordinator: TranscriptionCoordinatorProtocol
    private var cancellables = Set<AnyCancellable>()

    init(transcriptionCoordinator: TranscriptionCoordinatorProtocol) {
        self.transcriptionCoordinator = transcriptionCoordinator
        subscribeToTranscription()
    }

    /// Start live transcription
    func start() {
        guard !isRecording else { return }
        messages.removeAll()
        liveTranscription = nil
        isRecording = true
        isProcessing = true
        transcriptionCoordinator.startConversationTranscription()
    }

    /// Stop live transcription
    func stop() {
        guard isRecording else { return }
        isRecording = false
        isProcessing = false
        liveTranscription = nil
        transcriptionCoordinator.stopConversationTranscription()
    }

    private func subscribeToTranscription() {
        transcriptionCoordinator.conversationPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.isProcessing = false
                }
            }, receiveValue: { [weak self] update in
                // Show live transcription for partial results
                if !update.message.isFinal && update.message.content.count > 2 {
                    self?.liveTranscription = update.message.content
                } else if update.message.isFinal {
                    // Clear live transcription and add final message
                    self?.liveTranscription = nil
                    self?.messages.append(update.message)
                }
                self?.isProcessing = false
            })
            .store(in: &cancellables)
    }
}