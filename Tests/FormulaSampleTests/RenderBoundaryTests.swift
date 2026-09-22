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
        let store = FormulaStore(formula: DisplayFormula(), initialState: .init())
        let probe = RenderProbe()
        let view = FormulaView(store: store) { model in
            probe.parentValue = model.sibling
            return VStack {
                Text("\(model.sibling)")
                FormulaContent(model: model.child) { title in
                    probe.childRenders += 1
                    probe.childValue = title
                    return Text(title)
                }.equatable()
            }
        }
        let layout = host(view)
        await waitForRender(layout) { probe.childValue == "initial" }
        let initialRenders = probe.childRenders
        XCTAssertGreaterThan(initialRenders, 0)

        store.send { $0.sibling += 1 }
        await waitForRender(layout) { probe.parentValue == 1 }
        XCTAssertEqual(probe.childRenders, initialRenders)

        store.send { $0.child = "changed" }
        await waitForRender(layout) { probe.childValue == "changed" }
        XCTAssertGreaterThan(probe.childRenders, initialRenders)
        withExtendedLifetime(layout) {}
    }

    @MainActor
    private func waitForRender(_ layout: () -> Void, until rendered: () -> Bool) async {
        // Pump the actual host, yielding only to pending UI work, never sleeping.
        for _ in 0..<100 {
            layout()
            if rendered() { return }
            await Task.yield()
        }
        XCTFail("SwiftUI did not render the expected model")
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
    var parentValue = -1
    var childRenders = 0
    var childValue = ""
}

private struct DisplayFormula: Formula {
    struct State { var sibling = 0; var child = "initial" }
    struct RenderModel: Equatable { let sibling: Int; let child: String }
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(sibling: state.sibling, child: state.child)
    }
}
