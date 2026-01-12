# My Quiz App

這是一個使用 SwiftUI 開發的問答測驗 App。
透過簡單的功能來展示程式架構。

## 設定說明

為了保護 API Key，本專案使用了 `.xcconfig` 檔案。
上傳至 GitHub 的版本不包含敏感資訊。

### 如何執行？
1. 在專案根目錄建立一個 `Config.xcconfig` 檔案。
2. 貼入以下內容：
```config
SUPABASE_URL = https:/$()/你的網址
SUPABASE_ANON_KEY = 你的Key
