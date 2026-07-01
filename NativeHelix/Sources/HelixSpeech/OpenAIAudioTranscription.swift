import Foundation
import HelixCore

public protocol OpenAIAudioDataTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionOpenAIAudioDataTransport: OpenAIAudioDataTransport {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HelixError.providerFailure("OpenAI transcription returned a non-HTTP response.")
        }
        return (data, httpResponse)
    }
}

public struct OpenAIAudioFileTranscriber: AudioFileTranscriber {
    private let apiKey: String
    private let endpoint: URL
    private let transport: any OpenAIAudioDataTransport

    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.openai.com/v1")!,
        transport: any OpenAIAudioDataTransport = URLSessionOpenAIAudioDataTransport()
    ) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.endpoint = endpoint
        self.transport = transport
    }

    public func transcribeAudioFile(
        at url: URL,
        backend: TranscriptionBackend,
        model: String
    ) async throws -> TranscriptSegment {
        guard backend == .openAITranscription || backend == .openAIRealtime else {
            throw HelixError.unsupportedBackend(backend.rawValue)
        }

        let request = try makeURLRequest(fileURL: url, model: model)
        let (data, response) = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            _ = data
            throw HelixError.providerFailure("OpenAI transcription failed with HTTP \(response.statusCode).")
        }

        let payload = try JSONDecoder().decode(OpenAITranscriptionPayload.self, from: data)
        let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw HelixError.providerFailure("OpenAI transcription response was empty.")
        }
        return TranscriptSegment(text: text, isFinal: true, finalizedAt: Date())
    }

    public func makeURLRequest(fileURL: URL, model: String) throws -> URLRequest {
        guard !apiKey.isEmpty else {
            throw HelixError.missingApiKey("OpenAI")
        }

        let fileData = try Data(contentsOf: fileURL)
        let boundary = "helix-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint.appendingPathComponent("audio/transcriptions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(
            fileData: fileData,
            filename: fileURL.lastPathComponent,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4o-mini-transcribe" : model,
            boundary: boundary
        )
        return request
    }

    private static func multipartBody(
        fileData: Data,
        filename: String,
        model: String,
        boundary: String
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("\(model)\r\n")
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    private struct OpenAITranscriptionPayload: Decodable {
        var text: String
    }
}

public struct RealtimeSpeechSessionConfiguration: Equatable, Sendable {
    public var model: String
    public var sampleRate: Int
    public var languageCode: String?

    public init(
        model: String = "gpt-4o-mini-realtime",
        sampleRate: Int = 16_000,
        languageCode: String? = nil
    ) {
        self.model = model
        self.sampleRate = sampleRate
        self.languageCode = languageCode
    }
}

public enum RealtimeSpeechEvent: Equatable, Sendable {
    case partialTranscript(String)
    case finalTranscript(TranscriptSegment)
    case ended
}

public protocol RealtimeSpeechSession: Sendable {
    func events() -> AsyncStream<RealtimeSpeechEvent>
}

public struct DeterministicRealtimeSpeechSession: RealtimeSpeechSession {
    private let transcript: String

    public init(transcript: String = "What is retrieval augmented generation?") {
        self.transcript = transcript
    }

    public func events() -> AsyncStream<RealtimeSpeechEvent> {
        AsyncStream { continuation in
            Task {
                continuation.yield(.partialTranscript(transcript))
                continuation.yield(
                    .finalTranscript(
                        TranscriptSegment(text: transcript, isFinal: true, finalizedAt: Date())
                    )
                )
                continuation.yield(.ended)
                continuation.finish()
            }
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
