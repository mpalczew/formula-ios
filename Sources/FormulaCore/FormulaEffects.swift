import Foundation

@MainActor
final class FormulaEffects {
    private struct Owner {
        let scope: ObjectIdentifier
        let key: AnyHashable?
    }

    private var owners: [UUID: Owner] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]
    var activeCount: Int { owners.count }

    deinit { tasks.values.forEach { $0.cancel() } }

    func launch(
        in scope: FormulaScope, key: AnyHashable?,
        operation: @escaping @MainActor () async -> (() -> Void)
    ) {
        if let key { cancel(in: scope, key: key) }
        let id = UUID()
        owners[id] = Owner(scope: ObjectIdentifier(scope), key: key)
        tasks[id] = Task { @MainActor [weak self, weak scope] in
            guard !Task.isCancelled, scope?.isActive == true else {
                self?.finish(id)
                return
            }
            let complete = await operation()
            guard let self else { return }
            let active = self.finish(id)
            guard active, !Task.isCancelled, scope?.isActive == true else { return }
            complete()
        }
    }

    @discardableResult
    private func finish(_ id: UUID) -> Bool {
        tasks.removeValue(forKey: id)
        return owners.removeValue(forKey: id) != nil
    }

    func cancel(in scope: FormulaScope, key: AnyHashable? = nil) {
        let identity = ObjectIdentifier(scope)
        let ids = owners.filter { _, owner in
            owner.scope == identity && (key == nil || owner.key == key)
        }.map(\.key)
        for id in ids {
            owners.removeValue(forKey: id)
            tasks[id]?.cancel()
        }
    }

    /// Includes canceled operations until they actually return. Test fakes must
    /// release their continuations, including intentionally uncooperative ones.
    func waitUntilIdle() async {
        while !tasks.isEmpty {
            let pending = Array(tasks.values)
            for task in pending { await task.value }
        }
    }
}
