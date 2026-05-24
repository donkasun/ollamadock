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
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

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
        let ps = try decoder.decode(PSResponse.self, from: data)
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
        let tags = try decoder.decode(TagsResponse.self, from: data)
        return tags.models
    }

    func load(modelName: String) async throws {
        throw OllamaClientError.transport("not implemented")
    }
}
