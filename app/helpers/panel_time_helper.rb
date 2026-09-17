# Times drawn on a panel, on the app's 12- or 24-hour clock
# (AppSetting#clock). The formats are the panel_* entries under
# time.formats in config/locales/en.yml.
module PanelTimeHelper
  #   panel_time(now, :clock) # => "1:05", or "13:05" on a 24-hour clock
  def panel_time(time, style)
    l(time, format: :"panel_#{style}_#{AppSetting.current.clock}")
  end

  #   panel_date(now)        # => "Sep 7"
  #   panel_date(now, :long) # => "Monday, September 7, 2026"
  def panel_date(time, style = :short)
    l(time, format: :"panel_#{style}_date")
  end

  # How long ago something happened, as briefly as a headline's byline
  # line needs: "now", "5m", "3h", "2d".
  def panel_age(time, now)
    minutes = ((now - time) / 60).floor
    return t("renders.age.now") if minutes < 1
    return t("renders.age.minutes", count: minutes) if minutes < 60
    return t("renders.age.hours", count: minutes / 60) if minutes < 24 * 60

    t("renders.age.days", count: minutes / (24 * 60))
  end

  # "9/7 12:00p", or "9/7 12:00" on a 24-hour clock: a tile's event line
  # has room for little more.
  def event_time_label(event)
    date = event.starts_at.strftime("%-m/%-d")
    return "#{date} All day" if event.all_day

    time = panel_time(event.starts_at, :event)
    "#{date} #{AppSetting.current.clock == "12h" ? time.chop : time}"
  end
end
