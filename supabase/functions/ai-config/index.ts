// GameHub AI 配置助手 Edge Function
// 部署: supabase functions deploy ai-config --no-verify-jwt
// 环境变量: DEEPSEEK_API_KEY

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { prompt, gameType, currentBlocks } = await req.json();

    if (!prompt || !gameType) {
      return new Response(
        JSON.stringify({ error: "缺少 prompt 或 gameType" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const systemPrompt = `你是 GameHub 游戏配置助手。用户正在编辑一个 ${gameType} 游戏。
当前 Block 配置如下：
${JSON.stringify(currentBlocks, null, 2)}

用户说：「${prompt}」

请分析用户意图，返回 JSON 格式的修改方案（只返回 JSON，不要其他内容）：
{
  "explanation": "你的解释（中文）",
  "patches": [
    { "blockId": "blk_xxx", "config": { "key": "newValue" } }
  ],
  "newBlocks": [
    { "type": "collection", "label": "新卡堆", "config": {} }
  ]
}

规则：
1. 只修改现有 Block 的 config，不改变 block type
2. 如果用户要添加新内容（如新卡片、新建筑），用 newBlocks
3. 如果用户要改参数（如格数、金币、主题），用 patches，只传需要改的字段
4. 所有文案必须用中文，符合用户描述的主题风格
5. 只返回 JSON，不要其他内容`;

    const apiKey = Deno.env.get("DEEPSEEK_API_KEY") || "";
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "DEEPSEEK_API_KEY 未配置" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const response = await fetch("https://api.deepseek.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + apiKey,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        max_tokens: 4096,
        temperature: 0.7,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: prompt },
        ],
        response_format: { type: "json_object" },
      }),
    });

    const aiResponse = await response.json();

    if (aiResponse.error) {
      return new Response(
        JSON.stringify({ error: aiResponse.error.message || "AI API 错误" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const content = aiResponse.choices?.[0]?.message?.content || "";

    // 解析 AI 返回的 JSON
    let result;
    try {
      result = JSON.parse(content);
    } catch {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          result = JSON.parse(jsonMatch[0]);
        } catch {
          result = { error: "AI 返回格式异常", raw: content };
        }
      } else {
        result = { error: "AI 返回格式异常", raw: content };
      }
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
