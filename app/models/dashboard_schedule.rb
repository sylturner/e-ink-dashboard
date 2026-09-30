# Which of a panel's dashboards its schedule wants on it at a given time,
# and when that next changes (Device#apply_schedule!, Device#sleep_seconds).
#
# Each ScheduleSlot recurs on its days, from one time to another. When
# slots overlap, the one that began last wins: a daily 11:00-18:00 slot
# gives way to a Monday 12:00-17:00 one, and takes over again at 17:00.
# Between slots the panel shows the default dashboard, or keeps what it
# shows when there's none.
#
# The slots can be anything with an id, a dashboard_id, days (Date#wday
# numbers), a from_minute and an until_minute.
class DashboardSchedule
  # A stretch of the schedule: one slot's occurrence, or the gap between
  # slots. `key` tells stretches apart, so a panel can tell whether a new
  # one has begun since it last applied one. `dashboard_id` is nil in a
  # gap without a default.
  Cue = Data.define(:key, :dashboard_id, :slot)

  # A change is the time a new stretch begins, and its cue.
  Change = Data.define(:at, :cue)

  Occurrence = Data.define(:slot, :starts_at, :ends_at) do
    def cover?(time) = starts_at <= time && time < ends_at
    def length = ends_at - starts_at
  end

  DEFAULT_KEY = "default"
  MINUTES_PER_DAY = 24 * 60

  # A slot recurs at least weekly, so every change comes within a week.
  HORIZON = 8

  attr_reader :slots

  def initialize(slots, zone:, default_dashboard_id: nil)
    @slots = slots.sort_by(&:id)
    @zone = zone
    @default_dashboard_id = default_dashboard_id
  end

  def empty? = slots.empty?

  # The stretch under way at `time`, or nil when there is no schedule.
  def cue_at(time)
    return if empty?

    time = time.in_time_zone(@zone)
    occurrence = occurrences(time.to_date - 1, time.to_date).select { it.cover?(time) }.min_by do |it|
      [ -it.starts_at.to_i, it.length, slots.index(it.slot) ]
    end

    if occurrence
      Cue.new(key: "#{occurrence.slot.id}@#{occurrence.starts_at.to_i}", dashboard_id: occurrence.slot.dashboard_id, slot: occurrence.slot)
    else
      Cue.new(key: DEFAULT_KEY, dashboard_id: @default_dashboard_id, slot: nil)
    end
  end

  # The changes after `time`, soonest first, over the next week.
  def changes(time)
    return [].each if empty?

    time = time.in_time_zone(@zone)
    boundaries = occurrences(time.to_date - 1, time.to_date + HORIZON)
      .flat_map { [ it.starts_at, it.ends_at ] }
      .select { it > time }.uniq.sort

    Enumerator.new do |changes|
      key = cue_at(time).key
      boundaries.each do |at|
        cue = cue_at(at)
        next if cue.key == key

        changes << Change.new(at:, cue:)
        key = cue.key
      end
    end
  end

  # The next change that puts a dashboard on the panel. A gap without a
  # default leaves the panel as it is, so it isn't one.
  def next_switch(time)
    changes(time).find { it.cue.dashboard_id }
  end

  private

    def occurrences(first_date, last_date)
      (first_date..last_date).flat_map do |date|
        slots.select { it.days.include?(date.wday) }.map do |slot|
          ends_on = slot.until_minute > slot.from_minute ? date : date + 1
          Occurrence.new(slot:, starts_at: local(date, slot.from_minute), ends_at: local(ends_on, slot.until_minute))
        end
      end
    end

    # The wall-clock time on that date, however long the day is.
    def local(date, minute)
      @zone.local(date.year, date.month, date.day, minute / 60, minute % 60)
    end
end
