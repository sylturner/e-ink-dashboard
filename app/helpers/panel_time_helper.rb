# Times drawn on a panel, on the app's 12- or 24-hour clock
# (AppSetting#clock). The formats are the panel_* entries under
# time.formats in config/locales/en.yml.
module PanelTimeHelper
  #   panel_time(now, :clock) # => "1:05", or "13:05" on a 24-hour clock
  def panel_time(time, style)
    l(time, format: :"panel_#{style}_#{AppSetting.current.clock}")
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
