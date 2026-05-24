import XCTest
@testable import OllamaDock

final class OllamaClientTests: XCTestCase {
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func test_fetchRunning_decodes_running_models() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/ps")
            XCTAssertEqual(req.httpMethod, "GET")
            let data = try Data(
                contentsOf: Bundle(for: OllamaClientTests.self)
                    .url(forResource: "ps_running", withExtension: "json")!
            )
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OllamaClient(session: session())
        let models = try await client.fetchRunning()
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].name, "qwen3.6:27b-mlx")
        XCTAssertEqual(models[0].sizeVRAM, 19_000_000_000)
    }

    func test_fetchRunning_empty_models_returns_empty_array() async throws {
        MockURLProtocol.handler = { req in
            let data = try Data(
                contentsOf: Bundle(for: OllamaClientTests.self)
                    .url(forResource: "ps_empty", withExtension: "json")!
            )
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OllamaClient(session: session())
        let models = try await client.fetchRunning()
        XCTAssertTrue(models.isEmpty)
    }

    func test_fetchRunning_malformed_throws() async {
        MockURLProtocol.handler = { req in
            let data = try Data(
                contentsOf: Bundle(for: OllamaClientTests.self)
                    .url(forResource: "ps_malformed", withExtension: "json")!
            )
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OllamaClient(session: session())
        do {
            _ = try await client.fetchRunning()
            XCTFail("expected decoding error")
        } catch {
            // expected
        }
    }

    func test_fetchRunning_non200_throws_unreachable() async {
        MockURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = OllamaClient(session: session())
        do {
            _ = try await client.fetchRunning()
            XCTFail("expected error")
        } catch OllamaClientError.badStatus(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func test_unload_posts_keep_alive_zero() async throws {
        var capturedBody: Data?
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/generate")
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
            capturedBody = req.bodyStreamData() ?? req.httpBody
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = OllamaClient(session: session())
        try await client.unload(modelName: "qwen3.6:27b-mlx")

        let json = try XCTUnwrap(capturedBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        XCTAssertEqual(json["model"] as? String, "qwen3.6:27b-mlx")
        XCTAssertEqual(json["keep_alive"] as? Int, 0)
    }

    func test_fetchRunning_transport_failure_throws() async {
        MockURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let client = OllamaClient(session: session())
        do {
            _ = try await client.fetchRunning()
            XCTFail("expected transport error to propagate")
        } catch is URLError {
            // expected: URLSession throws the underlying URLError
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func test_fetchLibrary_decodes_tags_response() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/tags")
            XCTAssertEqual(req.httpMethod, "GET")
            let data = try Data(
                contentsOf: Bundle(for: OllamaClientTests.self)
                    .url(forResource: "tags_two_models", withExtension: "json")!
            )
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OllamaClient(session: session())
        let models = try await client.fetchLibrary()
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].name, "gemma4:e2b-mlx")
        XCTAssertEqual(models[0].sizeOnDisk, 7_069_822_916)
        XCTAssertEqual(models[1].name, "qwen3.6:27b-mlx")
    }

    func test_fetchLibrary_non200_throws_badStatus() async {
        MockURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = OllamaClient(session: session())
        do {
            _ = try await client.fetchLibrary()
            XCTFail("expected error")
        } catch OllamaClientError.badStatus(let code) {
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}

private extension URLRequest {
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
