import FormulaCore
import FormulaSwiftUI
import SwiftUI
import XCTest
#if os(iOS)
import UIKit
#else
import AppKit
#endif

final class RenderBoundaryTests: XCTestCase {
    @MainActor
    func testChangingSiblingDoesNotRenderUnchangedChild() async {
        let store = FormulaStore(formula: DisplayFormula())
        let probe = RenderProbe()
        let initial = expectation(description: "Initial child rendered")
        probe.childExpectation = ("initial", initial)
        let view = FormulaView(store: store) { model in
            probe.parentRendered(model.sibling)
            return VStack {
                Text("\(model.sibling)")
                FormulaContent(model: model.child) { title in
                    probe.childRendered(title)
                    return Text(title)
                }.equatable()
            }
        }
        let layout = host(view)
        layout()
        await waitForRender(initial)
        let initialRenders = probe.childRenders
        XCTAssertGreaterThan(initialRenders, 0)

        let sibling = expectation(description: "Sibling rendered")
        probe.parentExpectation = (1, sibling)
        store.send { $0.sibling += 1 }
        layout()
        await waitForRender(sibling)
        XCTAssertEqual(probe.childRenders, initialRenders)

        let changed = expectation(description: "Changed child rendered")
        probe.childExpectation = ("changed", changed)
        store.send { $0.child = "changed" }
        layout()
        await waitForRender(changed)
        XCTAssertGreaterThan(probe.childRenders, initialRenders)
        withExtendedLifetime(layout) {}
    }

    @MainActor
    private func waitForRender(_ rendered: XCTestExpectation) async {
        let result = await XCTWaiter.fulfillment(of: [rendered], timeout: 5)
        XCTAssertEqual(result, .completed, "SwiftUI did not render the expected model")
    }

    @MainActor
    private func host<Content: View>(_ content: Content) -> () -> Void {
        #if os(iOS)
        let controller = UIHostingController(rootView: content)
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        }
        window.rootViewController = controller
        window.isHidden = false
        return {
            window.layoutIfNeeded()
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
        #else
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        return { view.needsLayout = true; view.layoutSubtreeIfNeeded() }
        #endif
    }
}

@MainActor
private final class RenderProbe {
    var childRenders = 0
    var parentExpectation: (value: Int, signal: XCTestExpectation)?
    var childExpectation: (value: String, signal: XCTestExpectation)?

    func parentRendered(_ value: Int) {
        guard let expected = parentExpectation, expected.value == value else { return }
        parentExpectation = nil
        expected.signal.fulfill()
    }

    func childRendered(_ value: String) {
        childRenders += 1
        guard let expected = childExpectation, expected.value == value else { return }
        childExpectation = nil
        expected.signal.fulfill()
    }
}

private struct DisplayFormula: Formula {
    struct State { var sibling = 0; var child = "initial" }
    struct RenderModel: Equatable { let sibling: Int; let child: String }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(sibling: state.sibling, child: state.child)
    }
}
