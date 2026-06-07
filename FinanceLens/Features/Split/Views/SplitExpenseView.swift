import SwiftUI
import SwiftData

// MARK: - Split Model

@Model
final class SplitExpense {
    @Attribute(.unique) var id: UUID
    var title: String
    var totalAmount: Double
    var date: Date
    var participants: [SplitParticipant]
    var isSettled: Bool
    var createdAt: Date

    init(title: String, totalAmount: Double, date: Date = .now, participants: [SplitParticipant]) {
        self.id = UUID()
        self.title = title
        self.totalAmount = totalAmount
        self.date = date
        self.participants = participants
        self.isSettled = false
        self.createdAt = .now
    }
}

struct SplitParticipant: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var share: Double
    var hasPaid: Bool

    init(name: String, share: Double, hasPaid: Bool = false) {
        self.id = UUID()
        self.name = name
        self.share = share
        self.hasPaid = hasPaid
    }
}

// MARK: - Views

struct SplitExpenseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SplitExpense.createdAt, order: .reverse) private var splits: [SplitExpense]
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(splits) { split in
                NavigationLink { SplitDetailView(split: split) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(split.title).font(.headline)
                            Text("\(split.participants.count) people")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("₹\(split.totalAmount, specifier: "%.0f")").font(.subheadline.bold())
                            if split.isSettled {
                                Text("Settled").font(.caption).foregroundStyle(.green)
                            } else {
                                let pending = split.participants.filter { !$0.hasPaid }.count
                                Text("\(pending) pending").font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .onDelete { indexSet in
                for i in indexSet { context.delete(splits[i]) }
                try? context.save()
            }
        }
        .navigationTitle("Split Expenses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddSplitView() }
    }
}

struct AddSplitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var totalAmount = ""
    @State private var participantName = ""
    @State private var participants: [SplitParticipant] = []
    @State private var splitEvenly = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    TextField("Title (e.g. Dinner)", text: $title)
                    TextField("Total Amount (₹)", text: $totalAmount).keyboardType(.decimalPad)
                }

                Section("Participants") {
                    HStack {
                        TextField("Name", text: $participantName)
                        Button("Add") {
                            guard !participantName.isEmpty else { return }
                            participants.append(SplitParticipant(name: participantName, share: 0))
                            participantName = ""
                        }
                        .disabled(participantName.isEmpty)
                    }
                    ForEach(participants, id: \.id) { p in
                        Text(p.name)
                    }
                    .onDelete { participants.remove(atOffsets: $0) }
                }

                Section {
                    Toggle("Split Evenly", isOn: $splitEvenly)
                }
            }
            .navigationTitle("New Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .disabled(title.isEmpty || totalAmount.isEmpty || participants.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let total = Double(totalAmount) else { return }
        let share = total / Double(participants.count)
        let finalParticipants = participants.map { SplitParticipant(name: $0.name, share: share) }
        let split = SplitExpense(title: title, totalAmount: total, participants: finalParticipants)
        context.insert(split)
        try? context.save()
        dismiss()
    }
}

struct SplitDetailView: View {
    let split: SplitExpense
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section {
                HStack { Text("Total"); Spacer(); Text("₹\(split.totalAmount, specifier: "%.0f")").bold() }
                HStack { Text("Per Person"); Spacer(); Text("₹\(split.totalAmount / Double(max(1, split.participants.count)), specifier: "%.0f")") }
                HStack { Text("Date"); Spacer(); Text(split.date, style: .date) }
            }

            Section("Participants") {
                ForEach(Array(split.participants.enumerated()), id: \.element.id) { index, participant in
                    HStack {
                        Text(participant.name)
                        Spacer()
                        Text("₹\(participant.share, specifier: "%.0f")")
                            .foregroundStyle(.secondary)
                        Button {
                            split.participants[index].hasPaid.toggle()
                            split.isSettled = split.participants.allSatisfy(\.hasPaid)
                            try? context.save()
                        } label: {
                            Image(systemName: participant.hasPaid ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(participant.hasPaid ? .green : .gray)
                        }
                    }
                }
            }
        }
        .navigationTitle(split.title)
    }
}
