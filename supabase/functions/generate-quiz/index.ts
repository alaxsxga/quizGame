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
    const { topic, numberOfQuestions } = await req.json()
    // 2. 從環境變數讀取 Gemini API Key (待會我們要設定這個變數)
    const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
    const endpoint = `https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`

    console.log(`payload numOfQ:${numberOfQuestions} topic:${topic}`);
    // 3. 設定 Prompt (指令)
    const prompt = `
      我的主題是「${topic}」
      你是一個測驗專家。請針對主題產生 ${numberOfQuestions} 題單選題。
      
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
      Return ONLY the raw JSON array. No markdown, no "json" tags.
    `

    // 4. 呼叫 Gemini API
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }]
      })
    })

    const data = await response.json()
    console.log("Gemini Raw Data:", data);
    
    // 檢查是否有 candidates
    if (!data.candidates || data.candidates.length === 0) {
      const errMsg = data.error?.message || "Gemini 未回傳任何結果，請檢查 API Key 或主題內容。"
      throw new Error(errMsg)
    }

    // 5. 解析 Gemini 回傳的 JSON 字串
    let aiText = data.candidates[0].content.parts[0].text
    aiText = aiText.replace(/```json/g, '').replace(/```/g, '').trim()
    console.log("AI Text:", aiText);
    
    let cleanJsonString;
    try {
      const parsedJson = JSON.parse(aiText);
      if (!Array.isArray(parsedJson)) {
        throw new Error("Parsed result is not an array");
      }
      cleanJsonString = JSON.stringify(parsedJson, null, 0);
    } catch (parseError) {
      console.error("Parse failed after cleaning:", parseError);
      return new Response(JSON.stringify({ error: "Invalid JSON from Gemini", raw: aiText }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    return new Response(JSON.stringify(cleanJsonString), {
      headers: { 
        ...corsHeaders, 
        'Content-Type': 'text/plain; charset=utf-8',
      },
      status: 200,
    });

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
})