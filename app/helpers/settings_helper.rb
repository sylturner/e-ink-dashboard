module SettingsHelper
  # "12-hour (1:30 PM)" and "24-hour (13:30)", in the panels' own format.
  def clock_options
    sample = Time.zone.local(2026, 1, 1, 13, 30)

    AppSetting::CLOCKS.map { [ "#{it.to_i}-hour (#{l(sample, format: :"panel_time_#{it}")})", it ] }
  end

  def week_start_options
    AppSetting::WEEK_STARTS.map { [ it.capitalize, it ] }
  end
end
