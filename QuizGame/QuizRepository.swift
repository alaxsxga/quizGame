//
//  QuizRepository.swift
//  QuizGame
//
//  Created by Ed Liao on 2026/1/5.
//

import Foundation
import Supabase

protocol QuizRepository {
    func fetchAuthors() async throws -> [Author]
    func fetchQuestions(by authorId: UUID) async throws -> [Question]
    func generateQuestionsFromAI(for topic: String, numberOfQuestions: Int) async throws -> [Question]
}

enum SupabaseConfig {
    static var url: URL {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: urlString) else {
            fatalError("找不到 SupabaseURL，請檢查 Info.plist 與 xcconfig 設定")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String else {
            fatalError("找不到 SupabaseAnonKey，請檢查 Info.plist 與 xcconfig 設定")
        }
        return key
    }
}
 let supabaseClient = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)

// 實作 Supabase 版本的 Repository
class SupabaseQuizRepository: QuizRepository {
    private let client: SupabaseClient
    
    init(client: SupabaseClient = supabaseClient) {
        self.client = client
    }

    func fetchAuthors() async throws -> [Author] {
        let response = try await client
            .from("authors")
            .select("id, name, emoji, created_at")
            .execute()
        
        let decoder = JSONDecoder()
        return try decoder.decode([Author].self, from: response.data)
    }

    func fetchQuestions(by authorId: UUID) async throws -> [Question] {
        let response = try await client
            .from("questions")
            .select("*, options(*)")
            .eq("author_id", value: authorId.uuidString)
            .execute()
        
        let decoder = JSONDecoder()
        return try decoder.decode([Question].self, from: response.data)
    }
    
    // 呼叫 AI 生成題目的方法
    func generateQuestionsFromAI(for topic: String, numberOfQuestions: Int) async throws -> [Question] {
        // 定義 Edge Function 接收的酬載結構
        struct EdgeFunctionPayload: Encodable {
            let topic: String
            let numberOfQuestions: Int
        }
        
        let payload = EdgeFunctionPayload(topic: topic, numberOfQuestions: 2)
        let rawResponse: String = try await client.functions.invoke(
            "generate-quiz",
            options: FunctionInvokeOptions(
                headers: ["Content-Type": "application/json"],
                body: payload
            )
        )
        print("rawResponse: \(rawResponse)")
        
        guard let data = rawResponse.data(using: .utf8) else {
            throw NSError(domain: "EncodingError", code: -1, userInfo: nil)
        }
        if data.isEmpty {
            print("錯誤：Data 為空")
            throw NSError(domain: "EmptyData", code: -3, userInfo: nil)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            // 用 JSONSerialization 解析成 [[String: Any]]
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                throw NSError(domain: "JSONParseError", code: -1, userInfo: nil)
            }
            
            var aiQuestions: [AIQuestion] = []
            
            for json in jsonArray {
                guard let idStr = json["id"] as? String,
                      let uuid = UUID(uuidString: idStr),
                      let content = json["content"] as? String,
                      let optionsJson = json["options"] as? [[String: Any]] else {
                    print("某題缺少必要欄位，跳過")
                    continue
                }
                
                var options: [AIOption] = []
                for optJson in optionsJson {
                    guard let optIdStr = optJson["id"] as? String,
                          let optId = UUID(uuidString: optIdStr),
                          let optContent = optJson["content"] as? String,
                          let isCorrectAny = optJson["is_correct"] else {
                        continue
                    }
                    
                    // 處理 is_correct：支援 0/1 或 true/false
                    let isCorrect: Bool
                    if let boolVal = isCorrectAny as? Bool {
                        isCorrect = boolVal
                    } else if let intVal = isCorrectAny as? Int {
                        isCorrect = intVal == 1
                    } else if let numVal = isCorrectAny as? NSNumber {
                        isCorrect = numVal.boolValue
                    } else {
                        isCorrect = false
                    }
                    
                    let option = AIOption(id: optId, content: optContent, isCorrect: isCorrect)
                    options.append(option)
                }
                
                let aiQuestion = AIQuestion(id: uuid, content: content, options: options)
                aiQuestions.append(aiQuestion)
            }
            
            // 再轉換成完整 Question 結構（補上缺少的欄位）
            let questions: [Question] = aiQuestions.map { aiQ in
                let options = aiQ.options.map { aiOpt in
                    Option(
                        id: aiOpt.id,
                        questionId: aiQ.id,  // 用 question 的 id 關聯
                        content: aiOpt.content,
                        isCorrect: aiOpt.isCorrect,
                        createdAt: nil  // 暫時 nil，之後存資料庫再填
                    )
                }
                
                return Question(
                    id: aiQ.id,
                    authorId: nil,  // 之後再填
                    content: aiQ.content,
                    createdAt: nil,
                    options: options
                )
            }
            
            return questions
        } catch {
            print("Decode failed: \(error.localizedDescription)")
            throw error
        }
    }
}

//未來如果要換成 Firebase，只需在這裡實作新的 Repository
//class FirebaseQuizRepository: QuizRepository {
//    func fetchAuthors() async throws -> [Author] {
//        return []
//    }
//
//    func fetchQuestions(by authorId: UUID) async throws -> [Question] {
//        return []
//    }
//}

