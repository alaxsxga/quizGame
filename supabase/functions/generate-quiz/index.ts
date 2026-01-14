import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// 建立 CORS Header，讓你的 iOS App 可以跨域呼叫
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 處理瀏覽器或 SDK 的預檢請求 (Preflight request)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. 取得 App 傳過來的參數 (主題)
    const { topic } = await req.json()

    // 2. 從環境變數讀取 Gemini API Key (待會我們要設定這個變數)
    const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`

    // 3. 設定 Prompt (指令)
    const prompt = `
      你是一個測驗專家。請針對主題「${topic}」產生 5 題單選題。
      
      要求：
      1. 每題必須有 4 個選項。
      2. 正確答案必須「隨機」出現在四個選項中的任一位置。
      3. 必須回傳純 JSON 格式，不要包含 Markdown 標籤。
      
      JSON 結構範例：
      [
        {
          "id": "隨機UUID",
          "content": "題目內容",
          "options": [
            { "id": "隨機UUID", "content": "選項A", "is_correct": false },
            { "id": "隨機UUID", "content": "選項B", "is_correct": true },
            { "id": "隨機UUID", "content": "選項C", "is_correct": false },
            { "id": "隨機UUID", "content": "選項D", "is_correct": false }
          ]
        }
      ]
    `

    // 4. 呼叫 Gemini API
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json" // 強制要求 JSON
        }
      })
    })

    const data = await response.json()
    
    // 5. 解析 Gemini 回傳的 JSON 字串
    const aiText = data.candidates[0].content.parts[0].text
    
    // 6. 將結果回傳給 iOS App
    return new Response(aiText, {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})