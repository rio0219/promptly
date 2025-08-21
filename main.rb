require 'sinatra'
require 'line/bot'
require 'yaml'
require 'time'

require_relative './line_client'
require_relative './ai'

set :bind, '0.0.0.0'
set :port, 4567

USERS_FILE = "users.yml"

# LINEのWebhookエンドポイント
post '/callback' do
  body = request.body.read
  signature = request.env['HTTP_X_LINE_SIGNATURE']

  unless client.validate_signature(body, signature)
    halt 400, 'Bad Request'
  end

  events = client.parse_events_from(body)
  events.each do |event|
    case event
    when Line::Bot::Event::Message
      if event.type == Line::Bot::Event::MessageType::Text
        handle_message(event)
      end
    when Line::Bot::Event::Postback
      handle_postback(event)
    end
  end

  "OK"
end

# メッセージ受信処理
def handle_message(event)
  user_id = event['source']['userId']
  message = event.message['text']

  if message == "テーマ選択"
    # Quick Replyでテーマを提案
    client.reply_message(event['replyToken'], {
      type: 'text',
      text: 'テーマを選んでください',
      quickReply: {
        items: [
          { type: 'action', action: { type: 'postback', label: '冒険', data: 'theme=冒険' } },
          { type: 'action', action: { type: 'postback', label: '恋愛', data: 'theme=恋愛' } },
          { type: 'action', action: { type: 'postback', label: '日常', data: 'theme=日常' } }
        ]
      }
    })
  elsif message.start_with?("通知時間")
    # 例: 「通知時間 20:00」
    time = message.split(" ")[1]
    save_user_setting(user_id, "notify_time", time)
    client.reply_message(event['replyToken'], { type: 'text', text: "通知時間を #{time} に設定しました！" })
  else
    client.reply_message(event['replyToken'], { type: 'text', text: "「テーマ選択」または「通知時間 HH:MM」と送ってね" })
  end
end

# ポストバック処理（テーマ選択）
def handle_postback(event)
  user_id = event['source']['userId']
  data = CGI.parse(event['postback']['data'])
  theme = data["theme"].first
  save_user_setting(user_id, "theme", theme)

  client.reply_message(event['replyToken'], { type: 'text', text: "テーマ「#{theme}」を保存しました！" })
end

# ユーザー設定保存（YAML）
def save_user_setting(user_id, key, value)
  users = File.exist?(USERS_FILE) ? YAML.load_file(USERS_FILE) : { "users" => {} }
  users["users"][user_id] ||= {}
  users["users"][user_id][key] = value
  File.write(USERS_FILE, users.to_yaml)
end

# 通知ループ（非同期）
Thread.new do
  loop do
    users = File.exist?(USERS_FILE) ? YAML.load_file(USERS_FILE) : { "users" => {} }
    now = Time.now.strftime("%H:%M")

    users["users"].each do |user_id, settings|
      if settings["notify_time"] == now
        theme = settings["theme"] || "自由"
        idea = generate_idea(theme)
        client.push_message(user_id, { type: 'text', text: "今日のお題（#{theme}）: #{idea}" })
      end
    end

    sleep 60  # 1分ごとにチェック
  end
end
