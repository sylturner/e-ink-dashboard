# A countdown tile's words (Countdown), from renders.countdown.
module CountdownsHelper
  # A tile's Countdown at the panel's time.
  def countdown_for(item, now:)
    Countdown.new(date: item.setting("date"), time: item.setting("time"), unit: item.setting("unit"), now:)
  end

  # "3 days and 4 hours", from Countdown#remaining or a count of days.
  def countdown_time(counts)
    words = counts.map { |unit, count| t("renders.countdown.#{unit}", count:) }
    return words.first if words.one?

    t("renders.countdown.and", first: words.first, second: words.second)
  end

  # The whole count in a sentence: "12 days until Christmas", "Christmas
  # is today!", "3 days ago".
  def countdown_sentence(countdown, label:)
    named = label.present?

    case countdown.state
    when :ahead
      t("renders.countdown.sentence.#{named ? 'until' : 'to_go'}", time: countdown_time(countdown.remaining), label:)
    when :today
      named ? t("renders.countdown.sentence.today", label:) : t("renders.countdown.today")
    else
      t("renders.countdown.sentence.#{named ? 'since' : 'ago'}", time: countdown_time(days: countdown.days_since), label:)
    end
  end

  # For the big number: what goes under it. The first count is the number;
  # a second ("and 4 hours") joins the unit's word.
  def countdown_unit(counts)
    (unit, count), second = counts.to_a
    word = t("renders.countdown.unit.#{unit}", count:)
    return word if second.nil?

    t("renders.countdown.and", first: word, second: t("renders.countdown.#{second.first}", count: second.last))
  end

  # The line under the unit: "until Christmas", "to go", "since Christmas".
  def countdown_label(countdown, label:)
    named = label.present?

    case countdown.state
    when :ahead then named ? t("renders.countdown.until", label:) : t("renders.countdown.to_go")
    when :today then label
    else named ? t("renders.countdown.since", label:) : t("renders.countdown.ago")
    end
  end
end
