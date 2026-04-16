import Foundation

struct ModelUsage: Hashable {
    var model: String
    var input: Int = 0
    var cacheCreation: Int = 0
    var cacheRead: Int = 0
    var output: Int = 0

    var total: Int { input + cacheCreation + cacheRead + output }
}

struct UsageSnapshot {
    var total: ModelUsage
    var byModel: [ModelUsage]
}

struct UsageReader: Sendable {
    let claudeDir: URL

    init(claudeDir: URL = URL(fileURLWithPath: (NSString("~/.claude").expandingTildeInPath))) {
        self.claudeDir = claudeDir
    }

    func readTodayUsage() -> UsageSnapshot {
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]

        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())

        var seenIds = Set<String>()
        var perModel: [String: ModelUsage] = [:]

        let projectsDir = claudeDir.appendingPathComponent("projects")
        guard FileManager.default.fileExists(atPath: projectsDir.path),
              let enumerator = FileManager.default.enumerator(
                at: projectsDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return UsageSnapshot(total: ModelUsage(model: "Total"), byModel: [])
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            if let mod = values?.contentModificationDate, mod < startOfToday { continue }
            processFile(url: fileURL,
                        startOfToday: startOfToday,
                        isoFractional: isoFractional,
                        isoPlain: isoPlain,
                        seenIds: &seenIds,
                        perModel: &perModel)
        }

        var total = ModelUsage(model: "Total")
        for (_, u) in perModel {
            total.input += u.input
            total.cacheCreation += u.cacheCreation
            total.cacheRead += u.cacheRead
            total.output += u.output
        }

        let sorted = perModel.values.sorted { $0.total > $1.total }
        return UsageSnapshot(total: total, byModel: sorted)
    }

    private func processFile(url: URL,
                             startOfToday: Date,
                             isoFractional: ISO8601DateFormatter,
                             isoPlain: ISO8601DateFormatter,
                             seenIds: inout Set<String>,
                             perModel: inout [String: ModelUsage]) {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let timestampStr = obj["timestamp"] as? String
            else { continue }

            let ts = isoFractional.date(from: timestampStr) ?? isoPlain.date(from: timestampStr)
            guard let ts, ts >= startOfToday else { continue }

            guard let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }

            if let msgId = message["id"] as? String {
                if !seenIds.insert(msgId).inserted { continue }
            }

            let model = (message["model"] as? String) ?? "unknown"
            var entry = perModel[model] ?? ModelUsage(model: model)
            entry.input += (usage["input_tokens"] as? Int) ?? 0
            entry.cacheCreation += (usage["cache_creation_input_tokens"] as? Int) ?? 0
            entry.cacheRead += (usage["cache_read_input_tokens"] as? Int) ?? 0
            entry.output += (usage["output_tokens"] as? Int) ?? 0
            perModel[model] = entry
        }
    }
}
