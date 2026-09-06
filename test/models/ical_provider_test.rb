require "test_helper"

class IcalProviderTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 9, 5, 12)

  CALENDAR = <<~ICS
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//test//EN
    X-WR-CALNAME:Family
    BEGIN:VEVENT
    UID:one-off
    DTSTAMP:20260901T120000Z
    DTSTART:20260907T140000Z
    DTEND:20260907T150000Z
    SUMMARY:Dentist
    LOCATION:  High   Street#{'  '}
    END:VEVENT
    BEGIN:VEVENT
    UID:weekly
    DTSTAMP:20260901T120000Z
    DTSTART:20260902T090000Z
    DTEND:20260902T093000Z
    RRULE:FREQ=WEEKLY;BYDAY=WE
    SUMMARY:Standup
    END:VEVENT
    BEGIN:VEVENT
    UID:allday
    DTSTAMP:20260901T120000Z
    DTSTART;VALUE=DATE:20260910
    DTEND;VALUE=DATE:20260911
    SUMMARY:Bin day
    END:VEVENT
    END:VCALENDAR
  ICS

  # ical_providers(:two) is the fixture wired to a Source (and to a
  # webcal:// URL, which the stubbed Http.get makes irrelevant).
  setup { @provider = ical_providers(:two) }

  def fetch(body = CALENDAR)
    travel_to(NOW) { stub_method(Http, :get, returns: body) { @provider.fetch! } }
  end

  test "expands a recurring event into concrete occurrences" do
    events = fetch["events"].select { |e| e["uid"] == "weekly" }

    assert_operator events.size, :>, 5
    starts = events.map { |e| Time.parse(e["starts_at"]) }
    assert_equal starts.sort, starts, "occurrences should come out sorted"
    assert starts.all? { |t| t.wednesday? }, "weekly BYDAY=WE should stay on Wednesdays"
  end

  test "keeps one-off events and tidies their text" do
    event = fetch["events"].find { |e| e["uid"] == "one-off" }

    assert_equal "Dentist", event["title"]
    assert_equal "High Street", event["location"]
    assert_not event["all_day"]
  end

  test "marks all-day events and records their plain dates" do
    event = fetch["events"].find { |e| e["uid"] == "allday" }

    assert event["all_day"]
    # DTEND is exclusive for DATE values, so a one-day event ends the
    # same day it starts.
    assert_equal "2026-09-10", event["start_on"]
    assert_equal "2026-09-10", event["end_on"]
  end

  test "reports the window it expanded and the count" do
    payload = fetch

    assert_equal payload["events"].size, payload["count"]
    assert_equal (NOW.beginning_of_day - 1.day).iso8601, payload["window_from"]
    assert_equal (NOW + 60.days).iso8601, payload["window_to"]
  end

  test "labels events with the calendar name" do
    assert_equal [ "Family" ], fetch["events"].map { |e| e["calendar"] }.uniq
  end

  test "falls back to the source name when the calendar is unnamed" do
    body   = CALENDAR.sub("X-WR-CALNAME:Family\n", "")
    labels = fetch(body)["events"].map { |e| e["calendar"] }.uniq

    assert_equal [ @provider.source.name ], labels
  end

  test "skips an event that fails to expand instead of losing the rest" do
    broken = CALENDAR.sub("RRULE:FREQ=WEEKLY;BYDAY=WE", "RRULE:FREQ=NONSENSE")
    events = fetch(broken)["events"]

    assert_not_includes events.map { |e| e["uid"] }, "weekly"
    assert_includes events.map { |e| e["uid"] }, "one-off"
    assert_includes events.map { |e| e["uid"] }, "allday"
  end

  # Parsing is all-or-nothing in the icalendar gem, so a malformed date
  # cannot be skipped per-event. It has to surface as a fetch failure,
  # which leaves the last good payload on the panel.
  test "a malformed date fails the fetch and keeps the last good payload" do
    source = @provider.source
    source.record_success({ "events" => [ { "uid" => "old", "title" => "Kept" } ] })

    broken = CALENDAR.sub("DTSTART:20260907T140000Z", "DTSTART:nonsense")

    error = assert_raises(Http::Error) { fetch(broken) }
    assert_match(/could not parse calendar/, error.message)

    source.record_failure(error)
    assert_equal "Kept", source.reload.payload.dig("events", 0, "title")
    assert_equal 1, source.failure_count
  end

  test "raises when the body holds no calendar" do
    assert_raises(Http::Error) { fetch("not a calendar at all") }
  end

  test "rewrites webcal:// so Net::HTTP accepts it" do
    assert_match %r{\Awebcal://}, @provider.ical_url
    assert_equal "https://example.org/work.ics", @provider.send(:normalized_url)
  end

  test "the url is ciphertext at rest and plaintext through the model" do
    plain = @provider.ical_url
    assert_equal "webcal://example.org/work.ics", plain

    stored = ActiveRecord::Base.connection.select_value(
      "SELECT ical_url FROM ical_providers WHERE id = #{@provider.id}"
    )

    assert_not_equal plain, stored
    assert_not_includes stored, "example.org"
    assert_not_includes stored, "work.ics"

    envelope = JSON.parse(stored)
    assert envelope.key?("p"), "expected an Active Record Encryption envelope"
  end

  test "a newly saved url is encrypted too" do
    provider = IcalProvider.create!(ical_url: "https://secret.example.com/abc123.ics")

    stored = ActiveRecord::Base.connection.select_value(
      "SELECT ical_url FROM ical_providers WHERE id = #{provider.id}"
    )

    assert_not_includes stored, "abc123"
    assert_equal "https://secret.example.com/abc123.ics", provider.reload.ical_url
  end

  # Non-deterministic encryption means the same plaintext encrypts
  # differently every time, so the column cannot be used to correlate
  # two sources pointing at the same calendar.
  test "the same url encrypts to different ciphertext each time" do
    url = "https://example.com/same.ics"
    a = IcalProvider.create!(ical_url: url)
    b = IcalProvider.create!(ical_url: url)

    stored = ActiveRecord::Base.connection.select_all(
      "SELECT ical_url FROM ical_providers WHERE id IN (#{a.id}, #{b.id})"
    ).rows.flatten

    assert_not_equal stored.first, stored.second
    assert_equal [ url, url ], [ a.reload.ical_url, b.reload.ical_url ]
  end
end
