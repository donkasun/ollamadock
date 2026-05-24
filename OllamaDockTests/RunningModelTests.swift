import XCTest
@testable import OllamaDock

final class RunningModelTests: XCTestCase {
    func test_decodes_api_ps_payload() throws {
        let json = """
        {
          "models": [{
            "name": "qwen3.6:27b-mlx",
            "model": "qwen3.6:27b-mlx",
            "size": 19000000000,
            "digest": "60b0437bbd02",
            "expires_at": "2026-05-24T11:20:00Z",
            "size_vram": 19000000000
          }]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(PSResponse.self, from: json)

        XCTAssertEqual(response.models.count, 1)
        XCTAssertEqual(response.models[0].name, "qwen3.6:27b-mlx")
        XCTAssertEqual(response.models[0].sizeVRAM, 19_000_000_000)
    }

    func test_vramFraction_uses_provided_totalRAM() {
        let model = RunningModel(
            name: "x",
            sizeVRAM: 8_000_000_000,
            expiresAt: Date()
        )
        let fraction = model.vramFraction(ofTotalRAM: 32_000_000_000)
        XCTAssertEqual(fraction, 0.25, accuracy: 0.0001)
    }

    func test_vramFraction_clamps_to_one() {
        let model = RunningModel(name: "x", sizeVRAM: 100, expiresAt: Date())
        XCTAssertEqual(model.vramFraction(ofTotalRAM: 50), 1.0)
    }

    func test_vramFraction_zero_totalRAM_returns_zero() {
        let model = RunningModel(name: "x", sizeVRAM: 100, expiresAt: Date())
        XCTAssertEqual(model.vramFraction(ofTotalRAM: 0), 0.0)
    }

    func test_countdown_in_future_formats_minutes_seconds() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let model = RunningModel(
            name: "x",
            sizeVRAM: 1,
            expiresAt: now.addingTimeInterval(125)
        )
        XCTAssertEqual(model.countdownString(now: now), "2m 5s")
    }

    func test_countdown_under_minute_formats_seconds_only() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let model = RunningModel(
            name: "x",
            sizeVRAM: 1,
            expiresAt: now.addingTimeInterval(42)
        )
        XCTAssertEqual(model.countdownString(now: now), "42s")
    }

    func test_countdown_past_returns_unloading() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let model = RunningModel(
            name: "x",
            sizeVRAM: 1,
            expiresAt: now.addingTimeInterval(-10)
        )
        XCTAssertEqual(model.countdownString(now: now), "unloading…")
    }
}
