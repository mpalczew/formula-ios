import Foundation
import XCTest
@testable import FormulaNetworking

final class HTTPClientTests: XCTestCase {
    func testDecodesSuccessfulResponse() async throws {
        let client = HTTPClient { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("{\"name\":\"Formula\"}".utf8), response)
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let value: Payload = try await client.send(request)
        XCTAssertEqual(value.name, "Formula")
    }

    func testRejectsNonSuccessStatus() async {
        let client = HTTPClient { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)
        do {
            let _: Payload = try await client.send(request)
            XCTFail("Expected a status error")
        } catch let error as HTTPError {
            XCTAssertEqual(error, .status(503))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct Payload: Decodable {
    let name: String
}
