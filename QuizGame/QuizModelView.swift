//
//  QuizModelView.swift
//  QuizGame
//
//  Created by Ed Liao on 2026/1/5.
//

import Foundation

@MainActor
class QuizViewModel: ObservableObject {
    @Published var authors: [Author] = []
    @Published var questionsByAuthor: [Question] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 測驗狀態管理
    @Published var currentQuestionIndex = 0
    @Published var selectedOption: Option?
    @Published var isQuizFinished = false
    @Published var score = 0
    
    // 計時器相關
    @Published var timeRemaining = 10
    private var timerTask: Task<Void, Never>?
    
    private let getAuthorsUseCase: GetAuthorsUseCase
    private let getQuizQuestionsUseCase: GetQuizQuestionsUseCase
    private let generateQuizQuestionsUseCase: GenerateQuizQuestionsUseCase

    init(repository: SupabaseQuizRepository = SupabaseQuizRepository()) {
        let useCases = QuizUseCases.build(with: repository)
        self.getAuthorsUseCase = useCases.getAuthors
        self.getQuizQuestionsUseCase = useCases.getQuestions
        self.generateQuizQuestionsUseCase = useCases.generateQuizQuestions
    }

    // 取得當前題目
    var currentQuestion: Question? {
        guard !questionsByAuthor.isEmpty,
              currentQuestionIndex < questionsByAuthor.count else { return nil }
        return questionsByAuthor[currentQuestionIndex]
    }
    
    func loadAuthorsIfNeeded() async {
        guard authors.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            self.authors = try await getAuthorsUseCase.execute()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func startQuiz(for author: Author, questions: [Question]? = nil) async {
        isLoading = true
        errorMessage = nil
        questionsByAuthor = []
        currentQuestionIndex = 0
        selectedOption = nil
        isQuizFinished = false
        score = 0
        
        do {
            if let preloadedQuestions = questions {
                // 如果有預載題目，直接使用
                self.questionsByAuthor = preloadedQuestions
            } else {
                // 否則從資料庫獲取
                self.questionsByAuthor = try await getQuizQuestionsUseCase.execute(for: author.id)
            }
            isLoading = false
            if !self.questionsByAuthor.isEmpty {
                startTimer()
            } else {
                self.errorMessage = "未找到題目。請檢查或嘗試 AI 生成。"
            }
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // 呼叫 AI 生成題目並啟動測驗
    func generateQuizFromAI(for author: Author) async {
        isLoading = true
        errorMessage = nil
        questionsByAuthor = []
        
        do {
            let generatedQuestions = try await generateQuizQuestionsUseCase.execute(for: "台灣流行的網路迷因")
            await startQuiz(for: author, questions: generatedQuestions)
        } catch {
            self.errorMessage = "AI 生成題目失敗: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func startTimer() {
        stopTimer()
        timeRemaining = 10
        timerTask = Task {
            while timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                timeRemaining -= 1
            }
            nextQuestion()
        }
    }
    
    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    func nextQuestion() {
        stopTimer()
        if let selected = selectedOption, selected.isCorrect {
            score += 1
        }
        
        if currentQuestionIndex + 1 < questionsByAuthor.count {
            currentQuestionIndex += 1
            selectedOption = nil
            startTimer()
        } else {
            isQuizFinished = true
        }
    }
}

