import WidgetKit
import SwiftUI

// MARK: - Widget Data

struct SpendingEntry: TimelineEntry {
    let date: Date
    let todaySpent: Double
    let monthSpent: Double
    let budgetRemaining: Double
    let topCategory: String
}

// MARK: - Provider

struct SpendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry {
        SpendingEntry(date: .now, todaySpent: 450, monthSpent: 25000, budgetRemaining: 15000, topCategory: "Food")
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        let shared = UserDefaults(suiteName: "group.com.financelens.ai")
        let entry = SpendingEntry(
            date: .now,
            todaySpent: shared?.double(forKey: "todaySpent") ?? 0,
            monthSpent: shared?.double(forKey: "monthSpent") ?? 0,
            budgetRemaining: shared?.double(forKey: "budgetRemaining") ?? 0,
            topCategory: shared?.string(forKey: "topCategory") ?? "-"
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let entry: SpendingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "indianrupeesign.circle.fill")
                    .foregroundStyle(.blue)
                Text("FinanceLens")
                    .font(.caption2.bold())
            }
            Spacer()
            Text("Today")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("₹\(entry.todaySpent, specifier: "%.0f")")
                .font(.title2.bold())
            Text("This month: ₹\(entry.monthSpent, specifier: "%.0f")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let entry: SpendingEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("FinanceLens").font(.caption.bold())
                Spacer()
                Text("Today's Spending").font(.caption2).foregroundStyle(.secondary)
                Text("₹\(entry.todaySpent, specifier: "%.0f")").font(.title.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                statPill("Month", value: entry.monthSpent, color: .red)
                statPill("Budget Left", value: entry.budgetRemaining, color: .green)
                HStack(spacing: 4) {
                    Image(systemName: "chart.pie.fill").font(.caption2)
                    Text(entry.topCategory).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func statPill(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            Text("₹\(value, specifier: "%.0f")").font(.caption.bold()).foregroundStyle(color)
        }
    }
}

// MARK: - Widget Bundle Entry Point

//@main
struct FinanceLensWidgetBundle: WidgetBundle {
    var body: some Widget {
        FinanceLensWidget()
    }
}

// MARK: - Widget Definition

struct FinanceLensWidget: Widget {
    let kind = "FinanceLensWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendingProvider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetContentView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
            } else {
                WidgetContentView(entry: entry).padding().background()
            }
        }
        .configurationDisplayName("Spending Tracker")
        .description("View today's spending and monthly summary.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetContentView: View {
    @Environment(\.widgetFamily) var family
    let entry: SpendingEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}
