import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavingsGoal.createdAt, order: .reverse) private var goals: [SavingsGoal]
    @State private var showAdd = false
    @State private var selectedGoal: SavingsGoal?

    var body: some View {
        List {
            ForEach(goals.filter { !$0.isCompleted }) { goal in
                GoalRow(goal: goal)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedGoal = goal }
            }
            .onDelete { indexSet in
                for i in indexSet { context.delete(goals[i]) }
                try? context.save()
            }

            if !goals.filter(\.isCompleted).isEmpty {
                Section("Completed 🎉") {
                    ForEach(goals.filter(\.isCompleted)) { goal in
                        GoalRow(goal: goal).opacity(0.6)
                    }
                }
            }
        }
        .navigationTitle("Savings Goals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddGoalView() }
        .sheet(item: $selectedGoal) { goal in GoalDetailView(goal: goal) }
    }
}

struct GoalRow: View {
    let goal: SavingsGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.icon)
                Text(goal.name).font(.headline)
                Spacer()
                Text("\(Int(goal.progress * 100))%").font(.caption.bold())
                    .foregroundStyle(goal.isCompleted ? .green : .blue)
            }
            ProgressView(value: goal.progress)
                .tint(goal.isCompleted ? .green : .blue)
            HStack {
                Text("₹\(goal.savedAmount, specifier: "%.0f") / ₹\(goal.targetAmount, specifier: "%.0f")")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let days = goal.daysLeft {
                    Text("\(days) days left").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(86400 * 90)
    @State private var selectedIcon = "star.fill"

    private let icons = ["star.fill", "airplane", "house.fill", "car.fill", "gift.fill",
                          "laptopcomputer", "graduationcap.fill", "heart.fill", "trophy.fill"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal Name", text: $name)
                TextField("Target Amount (₹)", text: $targetAmount).keyboardType(.decimalPad)
                Toggle("Set Deadline", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))]) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .padding(8)
                                .background(selectedIcon == icon ? Color.blue.opacity(0.2) : .clear)
                                .clipShape(Circle())
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amt = Double(targetAmount), !name.isEmpty else { return }
                        let goal = SavingsGoal(name: name, targetAmount: amt,
                                              deadline: hasDeadline ? deadline : nil, icon: selectedIcon)
                        context.insert(goal)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || targetAmount.isEmpty)
                }
            }
        }
    }
}

struct GoalDetailView: View {
    let goal: SavingsGoal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var addAmount = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: goal.icon).font(.largeTitle).foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(goal.name).font(.title2.bold())
                            Text("₹\(goal.remaining, specifier: "%.0f") remaining")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ProgressView(value: goal.progress)
                        .tint(goal.isCompleted ? .green : .blue)
                        .scaleEffect(y: 2)
                        .padding(.vertical, 8)
                }

                Section("Progress") {
                    HStack { Text("Saved"); Spacer(); Text("₹\(goal.savedAmount, specifier: "%.0f")") }
                    HStack { Text("Target"); Spacer(); Text("₹\(goal.targetAmount, specifier: "%.0f")") }
                    if let daily = goal.dailyTarget {
                        HStack { Text("Daily target"); Spacer(); Text("₹\(daily, specifier: "%.0f")/day").foregroundStyle(.orange) }
                    }
                }

                if !goal.isCompleted {
                    Section("Add Savings") {
                        HStack {
                            TextField("₹ Amount", text: $addAmount).keyboardType(.decimalPad)
                            Button("Add") {
                                guard let amt = Double(addAmount) else { return }
                                goal.savedAmount += amt
                                if goal.savedAmount >= goal.targetAmount { goal.isCompleted = true }
                                try? context.save()
                                addAmount = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(addAmount.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
