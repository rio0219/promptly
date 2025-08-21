require "net/http"
require "json"
require "yaml"

class AI
  def initialize(api_key)
    @api_key = api_key
  end

  def generate_prompt(theme)
    uri = URI("https://api.openai.com/v1/chat/completions")
    req = Net::HTTP::Post.new(uri, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@api_key}"
    })
    req.body = {
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: "あなたはアイデアを出すアシスタントです。" },
        { role: "user", content: "テーマ「#{theme}」で取り組めるミニ課題を1つ提案してください。" }
      ],
      max_tokens: 100
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    json = JSON.parse(res.body)
    json["choices"][0]["message"]["content"].strip
  end
end
