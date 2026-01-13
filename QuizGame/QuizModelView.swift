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

    init(repository: SupabaseQuizRepository = SupabaseQuizRepository()) {
        let useCases = QuizUseCases.build(with: repository)
        self.getAuthorsUseCase = useCases.getAuthors
        self.getQuizQuestionsUseCase = useCases.getQuestions
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
        defer { isLoading = false }

        do {
            self.authors = try await getAuthorsUseCase.execute()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func startQuiz(for author: Author) async {
        isLoading = true
        questionsByAuthor = []
        currentQuestionIndex = 0
        selectedOption = nil
        isQuizFinished = false
        score = 0
        
        do {
            self.questionsByAuthor = try await getQuizQuestionsUseCase.execute(for: author.id)
            isLoading = false
            startTimer()
        } catch {
            self.errorMessage = error.localizedDescription
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

