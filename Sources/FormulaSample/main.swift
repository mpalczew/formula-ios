import FormulaCore
import FormulaLCE
import FormulaSwiftUI
import SwiftUI

public struct SharedHeader: Formula {
    public struct State { public var title: String }
    public struct RenderModel { public let title: String; public let onTap: () -> Void }
    public init() {}

    @MainActor public func render(state: State, context: FormulaContext<State>) -> RenderModel {
        RenderModel(title: state.title, onTap: context.callback { $0.title += " *" })
    }
}

public struct HomeScreen: Formula {
    public struct State {
        public var header = SharedHeader.State(title: "Home")
        public var count = 0
        public var message: String? = nil
        public var items: UCT<[String]> = .loading()
    }
    public struct RenderModel {
        public let header: SharedHeader.RenderModel
        public let count: Int
        public let message: String?
        public let items: UCT<[String]>
        public let increment: () -> Void
    }
    public init() {}

    @MainActor public func render(state: State, context: FormulaContext<State>) -> RenderModel {
        RenderModel(
            header: context.child(SharedHeader(), state: \.header),
            count: state.count,
            message: state.message,
            items: state.items,
            increment: context.callback {
                $0.count += 1
                $0.message = "Updated from Home"
                $0.items = .content(["Composed child", "Typed state"])
            }
        )
    }
}

public struct SettingsScreen: Formula {
    public struct State {
        public var header = SharedHeader.State(title: "Settings")
        public var enabled = false
    }
    public struct RenderModel {
        public let header: SharedHeader.RenderModel
        public let enabled: Bool
        public let toggle: () -> Void
    }
    public init() {}

    @MainActor public func render(state: State, context: FormulaContext<State>) -> RenderModel {
        RenderModel(
            header: context.child(SharedHeader(), state: \.header),
            enabled: state.enabled,
            toggle: context.callback { $0.enabled.toggle() }
        )
    }
}

public struct HomeScreenView: View {
    @StateObject private var store: FormulaStore<HomeScreen>
    public init(store: FormulaStore<HomeScreen>) { _store = StateObject(wrappedValue: store) }

    public var body: some View {
        FormulaView(store: store) { model in
            VStack(spacing: 20) {
                HeaderView(model: model.header)
                Text("Count: \(model.count)").font(.title)
                Button("Increment", action: model.increment)
                if let message = model.message { Text(message).foregroundStyle(.secondary) }
                switch model.items {
                case .loading: ProgressView("Loading items")
                case .content(let items): Text(items.joined(separator: " · ")).font(.subheadline)
                case .error: Text("Could not load items").foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

public struct SettingsScreenView: View {
    @StateObject private var store: FormulaStore<SettingsScreen>
    public init(store: FormulaStore<SettingsScreen>) { _store = StateObject(wrappedValue: store) }

    public var body: some View {
        FormulaView(store: store) { model in
            VStack(spacing: 20) {
                HeaderView(model: model.header)
                Toggle("Enabled", isOn: Binding(get: { model.enabled }, set: { _ in model.toggle() }))
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Settings")
        }
    }
}

private struct HeaderView: View {
    let model: SharedHeader.RenderModel
    var body: some View { Button(model.title, action: model.onTap).font(.headline).buttonStyle(.bordered) }
}

public struct FormulaSampleApp: App {
    public init() {}
    public var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { HomeScreenView(store: FormulaStore(formula: HomeScreen(), initialState: .init())) }
                    .tabItem { Label("Home", systemImage: "house") }
                NavigationStack { SettingsScreenView(store: FormulaStore(formula: SettingsScreen(), initialState: .init())) }
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        }
    }
}

FormulaSampleApp.main()
