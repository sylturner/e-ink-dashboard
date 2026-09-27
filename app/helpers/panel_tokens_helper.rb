# Tokens a tile's text can carry, filled in when the panel is drawn:
# "It's {{CURRENT_TIME}}" draws "It's 7:36 PM". A token with an argument
# takes it after a colon: {{DAYS_UNTIL:2026-12-25}}. A token that isn't
# one of these, or whose argument doesn't make sense, is drawn as typed,
# so a mistake shows on the panel instead of vanishing.
#
# A time is the time the frame was drawn, which is when the panel last
# checked in, not a ticking clock.
module PanelTokensHelper
  include PanelTimeHelper

  TOKEN = /\{\{\s*([A-Z_]+)(?:\s*:\s*([^{}]*?))?\s*\}\}/

  # Every token, in the order the inspector lists them, with an example
  # argument for those that take one.
  TOKENS = {
    "CURRENT_TIME" => nil, "CURRENT_DATE" => nil, "LONG_DATE" => nil, "WEEKDAY" => nil,
    "MONTH" => nil, "YEAR" => nil, "WEEK_NUMBER" => nil, "GREETING" => nil,
    "DAYS_UNTIL" => "2026-12-25", "DAYS_SINCE" => "2026-01-01", "SERVER_URL" => nil
  }.freeze

  # `text` with its tokens filled. Plain text is escaped; HTML that is
  # already safe (sanitized) is kept, and only the tokens' values are
  # escaped.
  def with_panel_tokens(text, now:)
    html = String.new(ERB::Util.html_escape(text.to_s))

    html.gsub(TOKEN) do
      match = Regexp.last_match
      value = panel_token(match[1], match[2], now)
      value.nil? ? match[0] : ERB::Util.html_escape(value)
    end.html_safe
  end

  # A token's value at `now`, or nil when it can't be filled.
  def panel_token(name, argument, now)
    case name
    when "CURRENT_TIME" then panel_time(now, :time)
    when "CURRENT_DATE" then panel_date(now)
    when "LONG_DATE"    then panel_date(now, :long)
    when "WEEKDAY"      then l(now.to_date, format: :panel_weekday)
    when "MONTH"        then l(now.to_date, format: :panel_month)
    when "YEAR"         then now.year.to_s
    # ISO 8601's week, which starts on Monday whatever the app's week does.
    when "WEEK_NUMBER"  then now.to_date.cweek.to_s
    when "GREETING"     then t("renders.tokens.greeting.#{part_of_day(now)}")
    when "DAYS_UNTIL", "DAYS_SINCE"
      date = token_date(argument) or return
      days = (date - now.to_date).to_i
      (name == "DAYS_UNTIL" ? days : -days).to_s
    when "SERVER_URL" then AppSetting.current.server_url.to_s
    end
  end

  private

    def token_date(argument)
      Date.iso8601(argument.to_s)
    rescue Date::Error
      nil
    end

    def part_of_day(now)
      case now.hour
      when 4...12  then "morning"
      when 12...17 then "afternoon"
      else "evening"
      end
    end
end
