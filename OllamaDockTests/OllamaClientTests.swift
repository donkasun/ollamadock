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
}
