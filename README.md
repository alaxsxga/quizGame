# Quiz Game - 多元題庫問答測驗

這是一個使用 SwiftUI 開發的問答測驗 App，結合了 Supabase 資料庫題庫與 AI 動態題目生成功能。

## 🚀 功能特色
- **分類測驗：** 支援多位作者的題庫選擇。
- **AI 即時生題：** 透過 Supabase Edge Functions 調用 AI 模型，即時產生全新的測驗內容。
- **互動機制：** 每題 10 秒倒數計時、視覺化答題進度條、即時結果反饋。
- **自動結算：** 測驗結束後自動統計並展示最終得分。

## 🛠 技術棧與架構模式
- **Frontend:** SwiftUI
- **Backend:** Supabase (Postgres 資料庫、Edge Functions 用於 AI 題目生成)
- **Architecture (MVVM + Repository Pattern):**
  - **ViewModel:** 管理測驗狀態、計時器邏輯。
  - **Use Case:** 封裝特定的業務邏輯（例如：開始挑戰、執行 AI 生成）。
  - **Repository:** 定義資料來源接口，將資料存取實作（如 Supabase）與上層邏輯隔離。

## 📦 設定說明

為了保護敏感資訊（API Keys），本專案使用了 `.xcconfig` 檔案進行設定。

1. 在專案根目錄建立一個 `Config.xcconfig` 檔案。
2. 貼入以下內容並填入您的 Supabase 資訊：
   ```config
   SUPABASE_URL = https:/$()/你的專案網址
   SUPABASE_ANON_KEY = 你的匿名Key
   ```
