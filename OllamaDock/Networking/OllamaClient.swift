import Foundation

enum OllamaClientError: Error, Equatable {
    case badStatus(Int)
    case transport(String)
}

protocol OllamaClienting: Sendable {
    func fetchRunning() async throws -> [RunningModel]
    func unload(modelName: String) async throws
    func fetchLibrary() async throws -> [LibraryModel]
    func load(modelName: String) async throws
}

final class OllamaClient: OllamaClienting {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // Held statically (not as a stored property) so OllamaClient stays
    // Sendable — JSONDecoder isn't Sendable. The decoder is configured once
    // and only ever read, so sharing one instance is safe.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = fractionalFormatter.date(from: raw)
                ?? plainFormatter.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unrecognized date format: \(raw)")
            )
        }
        return decoder
    }()

    // Ollama emits Go time.Time values that usually carry fractional seconds
    // (e.g. 2024-06-04T14:38:31.837-07:00). A single ISO8601DateFormatter
    // can't accept both fractional and whole-second forms, so try each.
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func fetchRunning() async throws -> [RunningModel] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/ps"))
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OllamaClientError.transport("non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaClientError.badStatus(http.statusCode)
        }
        let ps = try Self.decoder.decode(PSResponse.self, from: data)
        return ps.models
    }

    func unload(modelName: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": modelName, "keep_alive": 0]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OllamaClientError.transport("non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaClientError.badStatus(http.statusCode)
        }
    }

    func fetchLibrary() async throws -> [LibraryModel] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OllamaClientError.transport("non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaClientError.badStatus(http.statusCode)
        }
        let tags = try Self.decoder.decode(TagsResponse.self, from: data)
        return tags.models
    }

    func load(modelName: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": modelName, "keep_alive": 300]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OllamaClientError.transport("non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaClientError.badStatus(http.statusCode)
        }
    }
}
