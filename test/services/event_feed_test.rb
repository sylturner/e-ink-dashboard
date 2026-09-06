require "test_helper"

class EventFeedTest < ActiveSupport::TestCase
  ZONE = ActiveSupport::TimeZone["America/New_York"]

  setup do
    @item = dashboard_items(:two) # calendar
    @item.sources.destroy_all
  end

  def timed(uid, starts, ends, calendar: "Work", title: nil)
    { "uid" => uid, "title" => title || uid, "calendar" => calendar,
      "all_day" => false,
      "starts_at" => starts.iso8601, "ends_at" => ends.iso8601 }
  end

  def all_day(uid, start_on, end_on = nil, calendar: "Home")
    { "uid" => uid, "title" => uid, "calendar" => calendar, "all_day" => true,
      "start_on" => start_on, "end_on" => end_on || start_on,
      "starts_at" => "#{start_on}T00:00:00Z",
      "ends_at" => "#{end_on || start_on}T00:00:00Z" }
  end

  def attach(name, events)
    provider = IcalProvider.create!(ical_url: "https://example.com/#{name.parameterize}.ics")
    source = Source.create!(name: name, providable: provider,
                            refresh_seconds: 900, payload: { "events" => events })
    @item.sources << source
    source
  end

  test "merges every attached source and sorts by start time" do
    attach("Cal B", [ timed("b1", ZONE.parse("2026-09-07 15:00"),
                            ZONE.parse("2026-09-07 16:00"), calendar: "Cal B") ])
    attach("Cal A", [ timed("a1", ZONE.parse("2026-09-07 09:00"),
                            ZONE.parse("2026-09-07 10:00"), calendar: "Cal A"),
                      timed("a2", ZONE.parse("2026-09-08 09:00"),
                            ZONE.parse("2026-09-08 10:00"), calendar: "Cal A") ])

    feed = EventFeed.for(@item, zone: ZONE)

    assert_equal %w[a1 b1 a2], feed.map(&:title)
    assert_equal [ "Cal A", "Cal B", "Cal A" ], feed.map(&:calendar)
  end

  test "renders times in the requested zone" do
    attach("Cal", [ timed("noon", Time.utc(2026, 9, 7, 16), Time.utc(2026, 9, 7, 17)) ])

    event = EventFeed.for(@item, zone: ZONE).first
    assert_equal "12:00", event.time_label
    assert_equal Date.new(2026, 9, 7), event.starts_at.to_date
  end

  test "an all-day event stays on its own day in any zone" do
    attach("Cal", [ all_day("bins", "2026-09-10") ])

    event = EventFeed.for(@item, zone: ActiveSupport::TimeZone["Pacific/Auckland"]).first

    assert event.all_day
    assert_equal "All day", event.time_label
    assert event.on?(Date.new(2026, 9, 10))
    assert_not event.on?(Date.new(2026, 9, 9))
    assert_not event.on?(Date.new(2026, 9, 11)), "DTEND is exclusive for all-day events"
    assert_not event.multi_day?
  end

  test "a multi-day all-day event covers every day it spans" do
    attach("Cal", [ all_day("trip", "2026-09-10", "2026-09-12") ])

    event = EventFeed.for(@item, zone: ZONE).first

    assert event.multi_day?
    assert (10..12).all? { |d| event.on?(Date.new(2026, 9, d)) }
    assert_not event.on?(Date.new(2026, 9, 13))
  end

  test "a meeting booked to midnight does not spill into the next day" do
    attach("Cal", [ timed("late", ZONE.parse("2026-09-07 22:00"), ZONE.parse("2026-09-08 00:00")) ])

    event = EventFeed.for(@item, zone: ZONE).first

    assert event.on?(Date.new(2026, 9, 7))
    assert_not event.on?(Date.new(2026, 9, 8))
  end

  test "on_day, upcoming and between window the list" do
    attach("Cal", [
      timed("past",   ZONE.parse("2026-09-06 09:00"), ZONE.parse("2026-09-06 10:00")),
      timed("today",  ZONE.parse("2026-09-07 09:00"), ZONE.parse("2026-09-07 10:00")),
      timed("later",  ZONE.parse("2026-09-07 18:00"), ZONE.parse("2026-09-07 19:00")),
      timed("future", ZONE.parse("2026-09-20 09:00"), ZONE.parse("2026-09-20 10:00"))
    ])

    feed = EventFeed.for(@item, zone: ZONE)
    now  = ZONE.parse("2026-09-07 12:00")

    assert_equal %w[today later], EventFeed.on_day(feed, now.to_date).map(&:title)
    assert_equal %w[later future], EventFeed.upcoming(feed, now, 5).map(&:title)
    assert_equal %w[later], EventFeed.upcoming(feed, now, 1).map(&:title)
    assert_equal %w[past today later],
                 EventFeed.between(feed, ZONE.parse("2026-09-06 00:00"),
                                   ZONE.parse("2026-09-07 23:59")).map(&:title)
  end

  test "an item with no sources yields nothing" do
    assert_equal [], EventFeed.for(@item, zone: ZONE)
  end

  test "an untitled event still renders" do
    attach("Cal", [ timed("x", ZONE.parse("2026-09-07 09:00"),
                          ZONE.parse("2026-09-07 10:00"), title: "") ])

    assert_equal "(untitled)", EventFeed.for(@item, zone: ZONE).first.title
  end

  test "an unparseable timestamp is dropped rather than raising" do
    attach("Cal", [ { "uid" => "bad", "title" => "Bad", "all_day" => false,
                      "starts_at" => "", "ends_at" => "" } ])

    assert_equal [], EventFeed.for(@item, zone: ZONE)
  end
end
