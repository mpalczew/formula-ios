import XCTest
import FormulaCore
@testable import FormulaSample

final class SampleTests: XCTestCase {
    @MainActor
    func testSampleTargetExistsAndRuns() {
        let home = FormulaStore(formula: HomeScreen())
        home.renderModel.increment()
        XCTAssertEqual(home.state.count, 1)
        XCTAssertEqual(home.state.message, "Updated from Home")

        let settings = FormulaStore(formula: SettingsScreen())
        settings.renderModel.header.onTap()
        settings.renderModel.toggle()
        XCTAssertEqual(settings.renderModel.header.title, "Settings *")
        XCTAssertTrue(settings.state.enabled)
    }
}
