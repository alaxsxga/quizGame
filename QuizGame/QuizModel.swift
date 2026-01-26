//
//  QuizModel.swift
//  QuizGame
//
//  Created by Ed Liao on 2026/1/5.
//

import SwiftUI

struct Author: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let emoji: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case createdAt = "created_at"
    }
}

// 在 Author 結構的擴展中添加 AI 專用作者
extension Author {
    static let aiGenerated = Author(id: UUID(), name: "AI 生成題目", emoji: "🤖", createdAt: "")
}

struct Question: Codable, Identifiable, Hashable {
    let id: UUID
    let authorId: UUID?
    let content: String
    let createdAt: String?
    let options: [Option]

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case content
        case createdAt = "created_at"
        case options
    }

    static func == (lhs: Question, rhs: Question) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Option: Codable, Identifiable, Hashable {
    let id: UUID
    let questionId: UUID
    let content: String
    let isCorrect: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case questionId = "question_id"
        case content
        case isCorrect = "is_correct"
        case createdAt = "created_at"
    }

    static func == (lhs: Option, rhs: Option) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// AI 回傳專用結構
struct AIQuestion: Codable {
    let id: UUID
    let content: String
    let options: [AIOption]
}

struct AIOption: Codable, Identifiable {
    let id: UUID
    let content: String
    let isCorrect: Bool  // 直接用 Bool，JSON 的 0/1 會自動轉換
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case isCorrect = "is_correct"
    }
}

