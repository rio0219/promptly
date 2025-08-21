require "line/bot"

class LineClient
  def initialize(config)
    @client = Line::Bot::Client.new { |c|
      c.channel_secret = config["line_channel_secret"]
      c.channel_token = config["line_channel_token"]
    }
  end

  def reply(reply_token, messages)
    @client.reply_message(reply_token, messages)
  end

  def quick_reply_message(text, items)
    {
      type: "text",
      text: text,
      quickReply: {
        items: items.map { |label|
          {
            type: "action",
            action: {
              type: "message",
              label: label,
              text: label
            }
          }
        }
      }
    }
  end
end
