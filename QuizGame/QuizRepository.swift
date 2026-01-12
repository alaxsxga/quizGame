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

