import Foundation
import Combine

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var total: ModelUsage = ModelUsage(model: "Total")
    @Published private(set) var byModel: [ModelUsage] = []
    @Published private(set) var lastUpdated: Date = Date()
    @Published private(set) var isLoading: Bool = false

    private let reader = UsageReader()
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 10

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        let reader = self.reader
        Task.detached(priority: .userInitiated) {
            let snapshot = reader.readTodayUsage()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.total = snapshot.total
                self.byModel = snapshot.byModel
                self.lastUpdated = Date()
                self.isLoading = false
            }
        }
    }
}
