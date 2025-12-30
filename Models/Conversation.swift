import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), messages: [Message] = [], createdAt: Date = Date()) {
        self.id = id
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    mutating func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
    }

    mutating func clearMessages() {
        messages.removeAll()
        updatedAt = Date()
    }
}
