import FormulaCore
import SwiftUI

public struct FormulaView<F: Formula, Content: View>: View {
    @ObservedObject private var store: FormulaStore<F>
    private let content: (F.RenderModel) -> Content

    public init(store: FormulaStore<F>, @ViewBuilder content: @escaping (F.RenderModel) -> Content) {
        self.store = store
        self.content = content
    }

    public var body: some View {
        FormulaContent(model: store.renderModel, content: content).equatable()
    }
}

/// An equality boundary for a child render model. Every value that influences
/// this content must be represented in the model, rather than captured outside it.
public struct FormulaContent<Model: Equatable, Content: View>: Equatable {
    private let model: Model
    private let content: (Model) -> Content

    public init(model: Model, @ViewBuilder content: @escaping (Model) -> Content) {
        self.model = model
        self.content = content
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.model == rhs.model }
}

extension FormulaContent: View {
    public var body: some View { content(model) }
}
