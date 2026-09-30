# How a panel is set up and how it is doing, for its card, its page and
# the builder's device list.
module DevicesHelper
  # Wi-Fi strength by RSSI, strongest first, as [at least dBm, bars, word].
  SIGNAL_LEVELS = [
    [ -55, 4, "Excellent" ],
    [ -67, 3, "Good" ],
    [ -75, 2, "Fair" ],
    [ -85, 1, "Weak" ]
  ].freeze

  # Battery icons by charge, fullest first, as [at least percent, icon].
  BATTERY_LEVELS = [
    [ 80, "cil-battery-full" ],
    [ 50, "cil-battery-5" ],
    [ 20, "cil-battery-3" ]
  ].freeze

  # "800×480 · 1-bit bmp · 90°"
  def device_spec(device)
    [
      "#{device.width}×#{device.height}",
      "#{device.bit_depth}-bit #{device.image_format}",
      ("#{device.rotation}°" if device.rotation.to_i.nonzero?)
    ].compact.join(" · ")
  end

  # A badge for whether the panel is checking in on schedule, followed by
  # when it last did.
  def device_check_in(device)
    return status_badge("Never checked in", :secondary) if device.last_seen_at.nil?

    badge = device.overdue? ? status_badge("Overdue", :warning) : status_badge("Checked in", :success)
    safe_join([ badge, relative_time_tag(device.last_seen_at) ], " ")
  end

  # When the panel should check in next -- or, once that has passed, when
  # it was due.
  def device_next_check_in(device)
    due = device.next_check_in_at
    return "When it first connects" if due.nil?

    due.future? ? relative_time_tag(due) : safe_join([ "Was due", relative_time_tag(due) ], " ")
  end

  # The charge, with an icon to match and the voltage when it is reported.
  def device_battery(device)
    percent = device.battery_percent
    return not_reporting("cil-battery-slash") if percent.nil?

    icon = BATTERY_LEVELS.find { |least, _| percent >= least }&.last || "cil-battery-alert"
    text = "#{percent}%"
    text += " (#{number_with_precision(device.battery_voltage, precision: 2)} V)" if device.battery_voltage

    safe_join([ ui_icon(icon, classes: "icon me-1"), text ])
  end

  # The Wi-Fi strength in words and dBm, with signal bars to match.
  def device_signal(device)
    rssi = device.wifi_rssi
    return not_reporting("cil-wifi-signal-off") if rssi.nil?

    _, bars, word = SIGNAL_LEVELS.find { |least, *| rssi >= least } || [ nil, 0, "Very weak" ]

    safe_join([ ui_icon("cil-wifi-signal-#{bars}", classes: "icon me-1"), "#{word} (#{rssi} dBm)" ])
  end

  # The firmware version the panel last reported.
  def device_firmware(device)
    device.firmware_version.presence || not_reporting
  end

  # Choices for a daytime hour select, as 24-hour clock times. A saved
  # hour outside `hours` stays a choice, so the select shows it -- and
  # saving flags it -- rather than quietly showing, and saving, another.
  def hour_options(hours, current = nil)
    [ *hours, current ].compact.uniq.sort.map { [ format("%02d:00", it), it ] }
  end

  # The days of the week in the order the app's week starts, as
  # [abbreviation, full name, Date#wday], for a slot's day checkboxes.
  def schedule_day_options
    ScheduleSlot::DAYS.to_a.rotate(Date::DAYS_INTO_WEEK.fetch(Date.beginning_of_week)).map do |wday|
      [ t("date.abbr_day_names")[wday], t("date.day_names")[wday], wday ]
    end
  end

  # When a slot comes round: "Weekdays, 6:00 AM to 11:00 AM".
  def schedule_slot_when(slot)
    t("devices.schedule.when", days: schedule_slot_days(slot.days), times: schedule_slot_times(slot))
  end

  # "Every day", "Weekdays", "Mondays" or "Mon, Wed, Fri".
  def schedule_slot_days(days)
    days = days.sort
    return t("devices.schedule.days.every_day") if days == ScheduleSlot::DAYS.to_a
    return t("devices.schedule.days.weekdays") if days == ScheduleSlot::WEEKDAYS
    return t("devices.schedule.days.weekends") if days == ScheduleSlot::WEEKEND
    return t("devices.schedule.days.one", day: t("date.day_names")[days.first]) if days.one?

    schedule_day_options.filter_map { |abbr, _, wday| abbr if days.include?(wday) }.join(", ")
  end

  # "6:00 AM to 11:00 AM", "10:00 PM to 6:00 AM the next day" or "All day",
  # on the app's clock.
  def schedule_slot_times(slot)
    from, till = slot.from_minute, slot.until_minute
    return t("devices.schedule.times.all_day") if from.zero? && till.zero?

    key = till <= from && till.nonzero? ? "overnight" : "range"
    t("devices.schedule.times.#{key}", from: schedule_clock(from), until: schedule_clock(till))
  end

  # The schedule's line on a device's status: whether the panel is showing
  # what the schedule wants, and its next switch. Nil without a schedule.
  def device_schedule(device, now = Time.current)
    schedule = device.schedule
    return if schedule.empty?

    names = device.dashboards.to_h { [ it.id, it.name ] }
    cue = schedule.cue_at(now)
    lines = []

    if cue.dashboard_id && cue.dashboard_id != device.dashboard_id
      lines << if cue.key == device.schedule_cue
        t("devices.schedule.status.by_hand", dashboard: names[cue.dashboard_id])
      else
        t("devices.schedule.status.pending", dashboard: names[cue.dashboard_id])
      end
    end

    upcoming = schedule.changes(now).find { it.cue.dashboard_id && it.cue.dashboard_id != cue.dashboard_id }
    lines << if upcoming
      t("devices.schedule.status.next", dashboard: names[upcoming.cue.dashboard_id],
                                        at: schedule_switch_time(device.local_time(upcoming.at), device.local_time(now)))
    else
      t("devices.schedule.status.no_switches")
    end

    safe_join(lines, " ")
  end

  # When a switch comes, from `now`: "at 11:00 AM", "tomorrow at 6:00 AM",
  # "Monday at 12:00 PM", or "next Monday at 12:00 PM" a week out.
  def schedule_switch_time(at, now)
    time = panel_time(at, :time)
    days = (at.to_date - now.to_date).to_i

    case days
    when 0 then t("devices.schedule.at.today", time:)
    when 1 then t("devices.schedule.at.tomorrow", time:)
    when 2..6 then t("devices.schedule.at.this_week", time:, day: t("date.day_names")[at.wday])
    else t("devices.schedule.at.next_week", time:, day: t("date.day_names")[at.wday])
    end
  end

  private
    # A slot's minute after midnight on the app's clock.
    def schedule_clock(minute)
      panel_time(Time.utc(2000, 1, 1, *minute.divmod(60)), :time)
    end

    # An icon tells a card's battery and signal lines apart at a glance;
    # screen readers get a label before each.
    def not_reporting(icon = nil)
      tag.span class: "text-body-secondary" do
        safe_join([ (ui_icon(icon, classes: "icon me-1") if icon), "Not reporting" ].compact)
      end
    end
end
