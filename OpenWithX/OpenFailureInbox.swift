import Combine
import Foundation

/// One app-wide presentation queue. Deduplication IDs live only for this process lifetime.
@MainActor
final class OpenFailureInbox: ObservableObject {
    @Published private var pending: [OpenFailure] = []
    private var received: Set<UUID> = []

    var current: OpenFailure? { pending.first }

    @discardableResult
    func receive(_ url: URL) -> Bool {
        guard let failure = OpenFailure(handoffURL: url), received.insert(failure.id).inserted else { return false }
        pending.append(failure)
        return true
    }

    func dismiss() {
        guard !pending.isEmpty else { return }
        pending.removeFirst()
    }
}
