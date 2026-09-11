import FormulaCore
import SwiftUI

public struct FormulaView<F: Formula, Content: View>: View {
    @ObservedObject private var store: FormulaStore<F>
    private let content: (F.RenderModel) -> Content

    public init(
        store: FormulaStore<F>,
        @ViewBuilder content: @escaping (F.RenderModel) -> Content
    ) {
        self.store = store
        self.content = content
    }

    public var body: some View {
        content(store.renderModel)
    }
}
