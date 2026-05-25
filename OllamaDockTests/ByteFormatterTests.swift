import XCTest
@testable import OllamaDock

final class ByteFormatterTests: XCTestCase {
    func test_zero_bytes_renders_0GB() {
        XCTAssertEqual(ByteFormatter.format(0), "0 GB")
    }

    func test_nonzero_bytes_includes_a_unit() {
        let formatted = ByteFormatter.format(5_870_000_000)
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("MB"),
                      "expected a GB/MB unit, got \(formatted)")
    }
}
