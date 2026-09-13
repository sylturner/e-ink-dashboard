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

  private
    # An icon tells a card's battery and signal lines apart at a glance;
    # screen readers get a label before each.
    def not_reporting(icon = nil)
      tag.span class: "text-body-secondary" do
        safe_join([ (ui_icon(icon, classes: "icon me-1") if icon), "Not reporting" ].compact)
      end
    end
end
