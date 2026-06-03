import Foundation
import SwiftData

@Model
final class ChatSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]?

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var content: String
    var role: MessageRole
    var createdAt: Date
    var sources: [String]

    @Relationship(inverse: \ChatSession.messages)
    var session: ChatSession?

    init(content: String, role: MessageRole, sources: [String] = []) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.createdAt = .now
        self.sources = sources
    }
}

enum MessageRole: String, Codable {
    case user, assistant, system
}
