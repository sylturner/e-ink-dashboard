module ApplicationHelper
  # A time in words relative to now -- "3 hours ago", "in 5 minutes" --
  # with the exact time in the <time> element's datetime. `never` stands
  # in when there is no time.
  def relative_time_tag(time, never: "Never")
    return never if time.nil?

    words = time_ago_in_words(time)
    tag.time time.future? ? "in #{words}" : "#{words} ago", datetime: time.iso8601
  end

  # A builder for fields nested in a hash under the form's object, named
  # object[key][key]...: nested_fields(f, :settings, :template) builds
  # dashboard_item[settings][template][...]. There's no object to read
  # values from, so each field passes its own.
  def nested_fields(form, *keys)
    form.class.new("#{form.object_name}#{keys.map { "[#{it}]" }.join}", nil, self, form.options)
  end

  # A small status label, tinted by `tone` (:success, :warning, :danger,
  # :secondary). The subtle backgrounds and emphasis text meet contrast
  # in both themes.
  def status_badge(text, tone)
    tag.span text, class: "badge bg-#{tone}-subtle text-#{tone}-emphasis"
  end

  # Time zone choices valued by IANA name, as they are stored. Rails' zones
  # sharing one ("Edinburgh" and "London") make a single choice. A saved
  # zone that isn't among them stays a choice, so saving doesn't drop it.
  def time_zone_options(current = nil)
    options = ActiveSupport::TimeZone.all.group_by { it.tzinfo.name }.map do |name, zones|
      [ "(GMT#{zones.first.formatted_offset}) #{zones.map(&:name).join(", ")}", name ]
    end

    return options if current.blank? || options.any? { |_, name| name == current }

    options + [ [ current, current ] ]
  end
end
