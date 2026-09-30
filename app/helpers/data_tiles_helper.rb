# Fills a data tile's lines from its JSON source (DataTemplate), with the
# filters that draw a time on the panel's clock.
module DataTilesHelper
  include PanelTimeHelper

  # One line's text from `scope` (the data, or an entry of the list the
  # tile repeats for), or nil when all its values are empty.
  def data_line(format, scope, root:, now:)
    TokenLine.fill(format) do |name|
      token = DataTemplate.token(name)
      value = DataTemplate.lookup(token.path, scope, root:)

      DataTemplate::TIME_FILTERS.include?(token.filter) ? data_time(value, token.filter, now) : DataTemplate.filter(value, token)
    end
  end

  # The lines of a tile's template, one per line of the setting.
  def data_formats(text)
    text.to_s.lines.map(&:strip).compact_blank
  end

  private

    # A time in the data as the panel draws times: "7:36 PM", "Sep 28", or
    # how long since it or until it, "3h". Anything that isn't a time is
    # drawn as it is.
    def data_time(value, filter, now)
      time = DataTemplate.moment(value, now.time_zone)
      return DataTemplate.text(value) if time.nil?

      case filter
      when "time"  then panel_time(time, :time)
      when "date"  then panel_date(time)
      when "age"   then panel_age(time, now)
      when "until" then panel_age(now, time)
      end
    end
end
