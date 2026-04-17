import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider().opacity(0.5)
            content
            Spacer(minLength: 0)
            footer
        }
        .padding(14)
        .frame(minWidth: 260, minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Code — Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Formatting.grouped(store.total.total))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(spacing: 4) {
                Button(action: { store.refresh() }) {
                    Image(systemName: store.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .opacity(store.isLoading ? 0.6 : 1)
                }
                .buttonStyle(.borderless)
                .help("Refresh")
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Quit")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.byModel.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("No usage yet today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Run Claude Code and this will populate.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        } else {
            let maxTotal = max(store.byModel.first?.total ?? 1, 1)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.byModel, id: \.model) { m in
                    ModelRow(usage: m, maxTotal: maxTotal)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            breakdownChip("in", store.total.input, color: .gray)
            breakdownChip("cache", store.total.cacheCreation + store.total.cacheRead, color: .gray)
            breakdownChip("out", store.total.output, color: .gray)
            Spacer()
            Text(Formatting.relative(store.lastUpdated))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func breakdownChip(_ label: String, _ value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(Formatting.short(value))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

struct ModelRow: View {
    let usage: ModelUsage
    let maxTotal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle()
                    .fill(ModelStyle.color(for: usage.model))
                    .frame(width: 6, height: 6)
                Text(ModelStyle.displayName(for: usage.model))
                    .font(.system(.caption, design: .rounded))
                Spacer()
                Text(Formatting.short(usage.total))
                    .font(.system(.caption, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.08))
                    Capsule()
                        .fill(ModelStyle.color(for: usage.model))
                        .frame(width: g.size.width * CGFloat(Double(usage.total) / Double(maxTotal)))
                }
            }
            .frame(height: 4)
        }
    }
}

enum ModelStyle {
    static func displayName(for id: String) -> String {
        let lower = id.lowercased()
        if let name = tierVersion(tier: "opus", from: lower) { return name }
        if let name = tierVersion(tier: "sonnet", from: lower) { return name }
        if let name = tierVersion(tier: "haiku", from: lower) { return name }
        return id
    }

    private static func tierVersion(tier: String, from id: String) -> String? {
        guard id.contains(tier) else { return nil }
        let parts = id.split(separator: "-").map(String.init)
        guard let tierIdx = parts.firstIndex(of: tier) else {
            return tier.capitalized
        }
        // Take up to 2 short numeric components after the tier; skip long date-like numbers.
        let after = parts.dropFirst(tierIdx + 1)
        var versionParts: [String] = []
        for part in after {
            guard Int(part) != nil else { break }
            if part.count >= 6 { break } // date stamp like 20251001
            versionParts.append(part)
            if versionParts.count >= 2 { break }
        }
        let version = versionParts.joined(separator: ".")
        return version.isEmpty ? tier.capitalized : "\(tier.capitalized) \(version)"
    }

    static func color(for id: String) -> Color {
        let lower = id.lowercased()
        if lower.contains("opus") { return .purple }
        if lower.contains("sonnet") { return .blue }
        if lower.contains("haiku") { return .teal }
        return .gray
    }
}

@MainActor enum Formatting {
    private static let groupedFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    static func grouped(_ n: Int) -> String {
        groupedFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    static func short(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 10_000 { return String(format: "%.0fk", Double(n) / 1_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
