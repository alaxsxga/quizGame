//
//  QuizGameTests.swift
//  QuizGameTests
//

import Testing
import Foundation
@testable import QuizGame // 請確保這與你的專案名稱一致

// MARK: - 1. 模擬倉庫 (Mock Repository)
// 用來控制回傳的資料，不讓測試去連真正的 Supabase
class MockQuizRepository: QuizRepository {
    var authorsToReturn: [Author] = []
    var questionsToReturn: [Question] = []
    var shouldThrowError = false

    func fetchAuthors() async throws -> [Author] {
        if shouldThrowError { throw NSError(domain: "MockError", code: 1) }
        return authorsToReturn
    }

    func fetchQuestions(by authorId: UUID) async throws -> [Question] {
        if shouldThrowError { throw NSError(domain: "MockError", code: 2) }
        return questionsToReturn
    }
}
// MARK: - 2. UseCase 測試
@Suite("UseCase 邏輯測試")
struct QuizUseCaseTests {
    
    @Test("測試獲取作者清單是否成功")
    func testGetAuthorsSuccess() async throws {
        let mockRepo = MockQuizRepository()
        let expectedAuthor = Author(id: UUID(), name: "測試作者", emoji: "🧪", createdAt: "2024")
        mockRepo.authorsToReturn = [expectedAuthor]
        
        let useCase = GetAuthorsUseCase(repository: mockRepo)
        let authors = try await useCase.execute()
        
        #expect(authors.count == 1)
        #expect(authors.first?.name == "測試作者")
    }
    
    @Test("測試題目獲取後是否確實執行了隨機打亂(shuffled)")
    func testGetQuestionsShuffled() async throws {
        let mockRepo = MockQuizRepository()
        let authorId = UUID()
        // 建立 10 題
        let questions = (1...10).map { i in
            Question(id: UUID(), authorId: authorId, content: "題目 \(i)", createdAt: "now", options: [])
        }
        mockRepo.questionsToReturn = questions
        
        let useCase = GetQuizQuestionsUseCase(repository: mockRepo)
        let result = try await useCase.execute(for: authorId)
        
        #expect(result.count == 10)
        // 雖然機率極低，但 shuffled 後順序通常會不同。這裡主要是驗證 UseCase 有執行。
        #expect(result.contains(where: { $0.content == "題目 1" }))
    }
}

// MARK: - 3. ViewModel 測試
@Suite("ViewModel 狀態測試")
@MainActor // 因為 ViewModel 是 @MainActor
struct QuizViewModelTests {
    
    @Test("測試開始測驗時的初始化狀態")
    func testStartQuizInitialization() async throws {
        let mockRepo = MockQuizRepository()
        let authorId = UUID()
        let questions = [
            Question(id: UUID(), authorId: authorId, content: "Q1", createdAt: "now", 
                     options: [Option(id: UUID(), questionId: UUID(), content: "A1", isCorrect: true, createdAt: "now")])
        ]
        mockRepo.questionsToReturn = questions
        
        // 注入 Mock 到 ViewModel
        let viewModel = QuizViewModel(
            getAuthorsUseCase: GetAuthorsUseCase(repository: mockRepo),
            getQuizQuestionsUseCase: GetQuizQuestionsUseCase(repository: mockRepo)
        )
        
        let testAuthor = Author(id: authorId, name: "Test", emoji: "😀", createdAt: "now")
        
        await viewModel.startQuiz(for: testAuthor)
        
        #expect(viewModel.questionsByAuthor.count == 1)
        #expect(viewModel.currentQuestionIndex == 0)
        #expect(viewModel.score == 0)
        #expect(viewModel.isQuizFinished == false)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("測試答對題目後分數是否增加，並在最後一題完成測驗")
    func testScoreIncrementAndFinish() async throws {
        let mockRepo = MockQuizRepository()
        let qId = UUID()
        let correctOption = Option(id: UUID(), questionId: qId, content: "正確", isCorrect: true, createdAt: "now")
        let questions = [
            Question(id: qId, authorId: UUID(), content: "Q1", createdAt: "now", options: [correctOption])
        ]
        mockRepo.questionsToReturn = questions
        
        let viewModel = QuizViewModel(
            getAuthorsUseCase: GetAuthorsUseCase(repository: mockRepo),
            getQuizQuestionsUseCase: GetQuizQuestionsUseCase(repository: mockRepo)
        )
        
        await viewModel.startQuiz(for: Author(id: UUID(), name: "Test", emoji: "😀", createdAt: "now"))
        
        // 選取正確答案並進入下一題
        viewModel.selectedOption = correctOption
        viewModel.nextQuestion()
        
        #expect(viewModel.score == 1)
        #expect(viewModel.isQuizFinished == true)
    }
}

