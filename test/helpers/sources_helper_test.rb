require "test_helper"

class SourcesHelperTest < ActionView::TestCase
  setup do
    @source = sources(:one) # fetched, no failures
  end

  test "a healthy source is OK, with no error" do
    @rendered = source_health(@source)

    assert_select ".badge.bg-success-subtle", "OK"
    assert_select ".text-app-danger", 0
  end

  test "a failing source shows its failure count and last error" do
    @source.assign_attributes(failure_count: 2, last_error: "503 from example.com")

    @rendered = source_health(@source)

    assert_select ".badge.bg-danger-subtle", "2 failures"
    assert_select ".text-app-danger", "503 from example.com"
  end

  test "a source that has never been fetched says so" do
    @rendered = source_health(sources(:three))

    assert_select ".badge", "Not fetched"
  end

  test "the last fetch is a time element, or Never" do
    travel_to @source.fetched_at + 2.hours do
      @rendered = source_fetched_ago(@source)
    end

    assert_select "time[datetime=?]", @source.fetched_at.iso8601, "about 2 hours ago"
    assert_equal "Never", source_fetched_ago(sources(:three))
  end
end
