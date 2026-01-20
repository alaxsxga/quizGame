//
//  QestionsView.swift
//  QuizGame
//
//  Created by Ed Liao on 2025/12/30.
//

import SwiftUI

struct QestionsViewM: View {
    @StateObject var viewModel = QuizViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.authors) { author in
                NavigationLink(value: author) {
                    HStack(spacing: 15) {
                        Text(author.emoji)
                            .font(.system(size: 40))
                            .background(Circle().fill(Color.secondary.opacity(0.1)).frame(width: 50, height: 50))
                        
                        VStack(alignment: .leading) {
                            Text(author.name)
                                .font(.headline)
                            Text("點擊開始挑戰")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        // 新增 AI 題目生成按鈕
                        Button {
                            Task {
                                await viewModel.generateQuizFromAI(for: author)
                            }
                        } label: {
                            Label("AI 生成", systemImage: "sparkles")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.purple.opacity(0.1)))
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain) // 使用 .plain 樣式以避免預設按鈕的視覺效果
                        .disabled(viewModel.isLoading) // 在載入中時禁用按鈕
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("選擇作者")
            .task {
                await viewModel.loadAuthorsIfNeeded()
            }
            .overlay {
                // 處理載入和錯誤狀態的顯示
                if viewModel.isLoading && viewModel.authors.isEmpty {
                    ProgressView("載入作者中...")
                } else if viewModel.isLoading { // 當 isLoading 但 authors 不為空時，可能是 AI 正在生成題目
                    ProgressView("AI 正在生成題目中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial) // 輕微模糊背景
                        .cornerRadius(10)
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("發生錯誤", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("重試") {
                            Task {
                                // todo
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Author.self) { author in
                QuizPlayView(author: author)
            }
        }
        .environmentObject(viewModel)
    }
}

// MARK: 題目主畫面
struct QuizPlayView: View {
    let author: Author
    @EnvironmentObject var viewModel: QuizViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("準備題目中...")
            } else if viewModel.isQuizFinished {
                QuizResultView(score: viewModel.score, total: viewModel.questionsByAuthor.count) {
                    dismiss()
                }
            } else if let currentQuestion = viewModel.currentQuestion {
                QuizQuestionView(question: currentQuestion)
            } else {
                ContentUnavailableView("沒找到題目", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(author.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 如果 `questionsByAuthor` 已經被 AI 生成或從普通資料庫載入，
            // 這裡不需要再次呼叫 `startQuiz`。
            // `QuizViewModel` 的 `startQuiz` 方法應該只被呼叫一次來設置初始狀態。
            // 我們可以修改這裡，使其只在必要時啟動測驗（例如當題目尚未載入時）。
            // 由於 `QestionsViewM` 中的 AI 按鈕和 NavigationLink 都會觸發 `startQuiz`
            // 或 `generateQuizFromAI` 並最終設置 `questionsByAuthor`，
            // 這個 `.task` 塊將在 `QuizPlayView` 出現時執行。
            // `startQuiz` 內部會檢查 `questions: [Question]?` 是否為空。
            // 如果你希望每次進入 `QuizPlayView` 都重新獲取資料，則保留此處的 `await viewModel.startQuiz(for: author)`。
            // 但如果 AI 生成已經填充了 `questionsByAuthor`，再次呼叫可能會覆蓋。
            // 一個更安全的做法是檢查 `viewModel.questionsByAuthor` 是否為空。
            if viewModel.questionsByAuthor.isEmpty {
                await viewModel.startQuiz(for: author)
            }
        }
        .onDisappear {
            viewModel.stopTimer()
        }
    }
}

// MARK: 題目內容
struct QuizQuestionView: View {
    let question: Question
    @EnvironmentObject var viewModel: QuizViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("第 \(viewModel.currentQuestionIndex + 1) / \(viewModel.questionsByAuthor.count) 題")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ProgressView(value: Double(viewModel.currentQuestionIndex + 1), 
                         total: Double(viewModel.questionsByAuthor.count))
            
            Text(question.content)
                .font(.title2)
                .bold()
                .padding(.top, 5)
            
            QuizTimerView(timeRemaining: viewModel.timeRemaining)
                .padding(.vertical, 5)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(question.options) { option in
                        OptionRowView(option: option, isSelected: viewModel.selectedOption?.id == option.id) {
                            viewModel.selectedOption = option
                        }
                    }
                }
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    viewModel.nextQuestion()
                }
            } label: {
                Text(viewModel.currentQuestionIndex + 1 == viewModel.questionsByAuthor.count ? "完成" : "下一題")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedOption == nil)
        }
        .padding()
    }
}

// MARK: 題目選項
struct OptionRowView: View {
    let option: Option
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option.content)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                    .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
            )
        }
    }
}

// MARK: 計時器
struct QuizTimerView: View {
    let timeRemaining: Int
    
    var body: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining) / 10.0)
                    .stroke(timeRemaining <= 3 ? Color.red : Color.blue, lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timeRemaining)
                
                Text("\(timeRemaining)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(timeRemaining <= 3 ? .red : .primary)
            }
            .frame(width: 50, height: 50)
            Spacer()
        }
    }
}

// MARK: 結算畫面
struct QuizResultView: View {
    let score: Int
    let total: Int
    let onHomeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉 測驗完成！")
                .font(.largeTitle)
                .bold()
            
            VStack(spacing: 10) {
                Text("您的得分")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("\(score) / \(total)")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundColor(.blue)
            }
            .padding(40)
            .background(Circle().fill(Color.blue.opacity(0.1)))
            
            Button("回到首頁", action: onHomeAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

#Preview {
    QestionsViewM()
}

