import XCTest
@testable import FormulaCore

final class CompositionTests: XCTestCase {
    @MainActor
    func testInputChangeInvokesOnInputChanged() {
        let probe = Probe()
        let store = FormulaStore(formula: Leaf(name: "leaf", probe: probe), input: 1)
        store.update(input: 2)
        XCTAssertEqual(probe.inputChanges, ["leaf:1->2"])
        XCTAssertEqual(store.state.count, 0)
    }

    @MainActor
    func testInputChangeTriggersEvaluation() {
        let probe = Probe()
        let store = FormulaStore(formula: Leaf(name: "leaf", probe: probe), input: 1)
        store.update(input: 2)
        XCTAssertEqual(probe.renders["leaf"], 2)
        XCTAssertEqual(store.renderModel.input, 2)
    }

    @MainActor
    func testInputChangeIsIgnoredIfValueIsTheSame() {
        let probe = Probe()
        let store = FormulaStore(formula: Leaf(name: "leaf", probe: probe), input: 1)
        store.update(input: 1)
        XCTAssertEqual(probe.renders["leaf"], 1)
        XCTAssertTrue(probe.inputChanges.isEmpty)
    }

    @MainActor
    func testChildStateIsResetAfterToggle() {
        let probe = Probe()
        let store = FormulaStore(formula: Toggle(probe: probe))
        store.renderModel.child!.increment()
        XCTAssertEqual(store.renderModel.child?.count, 1)
        store.renderModel.toggle()
        XCTAssertNil(store.renderModel.child)
        store.renderModel.toggle()
        XCTAssertEqual(store.renderModel.child?.count, 0)
    }

    @MainActor
    func testChildStateChangeTriggersParentEvaluation() {
        let probe = Probe()
        let store = FormulaStore(formula: Tree(probe: probe))
        store.renderModel.a.increment()
        XCTAssertEqual(probe.renders["root"], 2)
        XCTAssertEqual(store.renderModel.a.count, 1)
    }

    @MainActor
    func testChildInputChangeTriggersEvaluation() {
        let probe = Probe()
        let store = FormulaStore(formula: Tree(probe: probe))
        store.renderModel.bumpA()
        XCTAssertEqual(probe.renders["a"], 2)
        XCTAssertEqual(probe.inputChanges, ["a:0->1"])
        XCTAssertEqual(store.renderModel.a.input, 1)
    }

    @MainActor
    func testKeyScopesChildFormula() {
        let probe = Probe()
        let store = FormulaStore(formula: Tree(probe: probe))
        store.renderModel.a.increment()
        XCTAssertEqual(store.renderModel.a.count, 1)
        XCTAssertEqual(store.renderModel.b.count, 0)
    }

    @MainActor
    func testParentRemovesChildWhenChildCallsCallbackFromInput() {
        let store = FormulaStore(formula: Closable())
        let child = store.renderModel.child!
        child.finish()
        XCTAssertNil(store.renderModel.child)
        child.finish()
        XCTAssertNil(store.renderModel.child)
    }

    @MainActor
    func testUnchangedChildIsNotEvaluatedWhenSiblingChanges() {
        let probe = Probe()
        let store = FormulaStore(formula: Tree(probe: probe))
        store.renderModel.bumpA()
        XCTAssertEqual(probe.renders["a"], 2)
        XCTAssertEqual(probe.renders["b"], 1)
        XCTAssertEqual(probe.renders["mid"], 1)
    }

    @MainActor
    func testUnchangedChildrenAreNotEvaluatedWhenParentChanges() {
        let probe = Probe()
        let store = FormulaStore(formula: Tree(probe: probe))
        store.renderModel.bumpOther()
        XCTAssertEqual(probe.renders["root"], 2)
        XCTAssertEqual(probe.renders["a"], 1)
        XCTAssertEqual(probe.renders["b"], 1)
        XCTAssertEqual(probe.renders["mid"], 1)
        XCTAssertEqual(probe.renders["grand"], 1)
    }

    @MainActor
    func testNonEquatableInputIsTreatedAsChanged() {
        let probe = Probe()
        let store = FormulaStore(formula: OpaqueParent(probe: probe))
        store.renderModel.bump()
        XCTAssertEqual(probe.renders["opaque"], 2)
    }

    @MainActor
    func testSkippedChildKeepsCallbacksAndGrandchildrenAlive() {
        let probe = Probe()
        let store = FormulaStore(formula: Tree(probe: probe))
        let first = store.renderModel
        store.renderModel.bumpOther()
        let second = store.renderModel
        XCTAssertEqual(first.a.increment, second.a.increment)
        XCTAssertEqual(first.mid.grand.increment, second.mid.grand.increment)
        first.a.increment()
        first.mid.grand.increment()
        XCTAssertEqual(store.renderModel.a.count, 1)
        XCTAssertEqual(store.renderModel.mid.grand.count, 1)
    }

    @MainActor
    func testGrandchildTransitionEvaluatesAncestorsButNotUnchangedSiblings() {
        let probe = Probe()
        let store = FormulaStore(formula: Tree(probe: probe))
        store.renderModel.mid.grand.increment()
        XCTAssertEqual(probe.renders["root"], 2)
        XCTAssertEqual(probe.renders["mid"], 2)
        XCTAssertEqual(probe.renders["grand"], 2)
        XCTAssertEqual(probe.renders["a"], 1)
        XCTAssertEqual(probe.renders["b"], 1)
        XCTAssertEqual(store.renderModel.mid.grand.count, 1)
    }
}

@MainActor
private final class Probe {
    var renders: [String: Int] = [:]
    var inputChanges: [String] = []
}

private struct Leaf: Formula {
    let name: String
    let probe: Probe
    struct State { var count = 0 }
    struct RenderModel: Equatable { let input: Int; let count: Int; let increment: Callback<Void> }
    func initialState(input: Int) -> State { State() }
    func onInputChanged(old: Int, new: Int, state: inout State) {
        probe.inputChanges.append("\(name):\(old)->\(new)")
    }
    func render(input: Int, state: State, context: FormulaContext<Self>) -> RenderModel {
        probe.renders[name, default: 0] += 1
        return .init(input: input, count: state.count, increment: context.callback { $0.count += 1 })
    }
}

private struct Mid: Formula {
    let probe: Probe
    struct RenderModel: Equatable { let grand: Leaf.RenderModel }
    func initialState(input: Void) {}
    func render(input: Void, state: Void, context: FormulaContext<Self>) -> RenderModel {
        probe.renders["mid", default: 0] += 1
        return .init(grand: context.child(Leaf(name: "grand", probe: probe), input: 0))
    }
}

private struct Tree: Formula {
    let probe: Probe
    struct State { var a = 0; var b = 0; var other = 0 }
    struct RenderModel: Equatable {
        let a: Leaf.RenderModel
        let b: Leaf.RenderModel
        let mid: Mid.RenderModel
        let bumpA: Callback<Void>
        let bumpOther: Callback<Void>
    }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        probe.renders["root", default: 0] += 1
        return .init(
            a: context.child(Leaf(name: "a", probe: probe), input: state.a, key: "a"),
            b: context.child(Leaf(name: "b", probe: probe), input: state.b, key: "b"),
            mid: context.child(Mid(probe: probe)),
            bumpA: context.callback { $0.a += 1 },
            bumpOther: context.callback { $0.other += 1 }
        )
    }
}

private struct Toggle: Formula {
    let probe: Probe
    struct State { var show = true }
    struct RenderModel: Equatable { let child: Leaf.RenderModel?; let toggle: Callback<Void> }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(
            child: state.show ? context.child(Leaf(name: "leaf", probe: probe), input: 0) : nil,
            toggle: context.callback { $0.show.toggle() }
        )
    }
}

private struct Closer: Formula {
    struct RenderModel: Equatable { let finish: Callback<Void> }
    func initialState(input: Callback<Void>) {}
    func render(input: Callback<Void>, state: Void, context: FormulaContext<Self>) -> RenderModel {
        .init(finish: context.callback { _ in input() })
    }
}

private struct Closable: Formula {
    struct State { var isOpen = true }
    struct RenderModel: Equatable { let child: Closer.RenderModel? }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(child: state.isOpen
            ? context.child(Closer(), input: context.callback { $0.isOpen = false })
            : nil)
    }
}

private struct Opaque { let run: () -> Void }

private struct OpaqueChild: Formula {
    let probe: Probe
    func initialState(input: Opaque) {}
    func render(input: Opaque, state: Void, context: FormulaContext<Self>) -> Int {
        probe.renders["opaque", default: 0] += 1
        return 0
    }
}

private struct OpaqueParent: Formula {
    let probe: Probe
    struct State { var count = 0 }
    struct RenderModel: Equatable { let bump: Callback<Void> }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        _ = context.child(OpaqueChild(probe: probe), input: Opaque(run: {}))
        return .init(bump: context.callback { $0.count += 1 })
    }
}
