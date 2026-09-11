import XCTest
@testable import FormulaLCE

final class LCETests: XCTestCase {
    func testMapContentPreservesLoadingAndError() {
        XCTAssertEqual(LCE<Int, String, String>.loading(1).mapContent(\.count), .loading(1))
        XCTAssertEqual(LCE<Int, String, String>.content("hi").mapContent(\.count), .content(2))
        XCTAssertEqual(LCE<Int, String, String>.error("bad").mapContent(\.count), .error("bad"))
    }

    func testAllAliasesCompile() {
        let _: UCE<String, String> = .loading()
        let _: UCT<String> = .loading()
        let _: CE<String, String> = .content("ok")
        let _: CT<String> = .error(TestError.failed)
        let _: LC<String, String> = .loading("working")
        let _: UC<String> = .content("ok")
    }
}

private enum TestError: Error { case failed }
