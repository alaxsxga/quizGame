//
//  QuizUseCases.swift
//  QuizGame
//
//  Created by Ed Liao on 2026/1/5.
//

import Foundation

// 聚合所有與測驗相關的 UseCases，方便一次性注入
struct QuizUseCases {
    let getAuthors: GetAuthorsUseCase
    let getQuestions: GetQuizQuestionsUseCase

    static func build(with repository: QuizRepository) -> QuizUseCases {
        QuizUseCases(
            getAuthors: GetAuthorsUseCase(repository: repository),
            getQuestions: GetQuizQuestionsUseCase(repository: repository)
        )
    }
}

// 獲取作者清單的 UseCase
struct GetAuthorsUseCase {
    private let repository: QuizRepository
    
    init(repository: QuizRepository) {
        self.repository = repository
    }
    
    func execute() async throws -> [Author] {
        return try await repository.fetchAuthors()
    }
}

// 獲取題目並處理的 UseCase
struct GetQuizQuestionsUseCase {
    private let repository: QuizRepository
    
    init(repository: QuizRepository) {
        self.repository = repository
    }
    
    func execute(for authorId: UUID) async throws -> [Question] {
        let questions = try await repository.fetchQuestions(by: authorId)
        // 這裡可以加入邏輯，例如：隨機排序題目
        return questions.shuffled() 
    }
}

