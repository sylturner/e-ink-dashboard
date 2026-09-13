module ApplicationHelper
  # A time in words relative to now -- "3 hours ago", "in 5 minutes" --
  # with the exact time in the <time> element's datetime. `never` stands
  # in when there is no time.
  def relative_time_tag(time, never: "Never")
    return never if time.nil?

    words = time_ago_in_words(time)
    tag.time time.future? ? "in #{words}" : "#{words} ago", datetime: time.iso8601
  end

  # A small status label, tinted by `tone` (:success, :warning, :danger,
  # :secondary). The subtle backgrounds and emphasis text meet contrast
  # in both themes.
  def status_badge(text, tone)
    tag.span text, class: "badge bg-#{tone}-subtle text-#{tone}-emphasis"
  end
end
