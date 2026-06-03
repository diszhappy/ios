import SwiftUI

struct ChatView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var chatEngine = FinancialChatEngine()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if chatEngine.messages.isEmpty {
                                suggestionsView
                            }
                            ForEach(chatEngine.messages, id: \.id) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                            if chatEngine.isProcessing {
                                HStack {
                                    ProgressView()
                                    Text("Analyzing...").foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatEngine.messages.count) {
                        if let last = chatEngine.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                Divider()
                inputBar
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") { chatEngine.clearHistory() }
                }
            }
            .onAppear { chatEngine.setup(context: context) }
        }
    }

    private var suggestionsView: some View {
        VStack(spacing: 12) {
            Text("Ask me about your finances")
                .font(.headline)
                .padding(.top, 40)

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    inputText = suggestion
                    sendMessage()
                } label: {
                    Text(suggestion)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about your finances...", text: $inputText)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty || chatEngine.isProcessing)
        }
        .padding()
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        Task { await chatEngine.sendMessage(text) }
    }

    private let suggestions = [
        "How much did I spend this month?",
        "What are my subscriptions?",
        "Show my budget status",
        "Predict next month's spending",
        "What's my financial health score?"
    ]
}

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if !message.sources.isEmpty {
                    Text("Source: \(message.sources.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if message.role == .assistant { Spacer() }
        }
    }
}
