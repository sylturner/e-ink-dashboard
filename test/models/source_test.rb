require "test_helper"

class SourceTest < ActiveSupport::TestCase
  setup do
    @weather = sources(:one)   # on dashboard_items(:one)
    @spare   = sources(:three) # never fetched, unused
  end

  test "kind_label names the provider in plain language" do
    assert_equal "Weather", @weather.kind_label
    assert_equal "RSS feed", @spare.kind_label
    assert_equal "Calendar (iCal)", sources(:two).kind_label
  end

  test "healthy? needs a successful fetch and no failures" do
    assert @weather.healthy?

    @weather.update!(failure_count: 2)
    assert_not @weather.healthy?

    @weather.update!(failure_count: 0, fetched_at: nil)
    assert_not @weather.healthy?
  end

  test "stale? is true until the first fetch" do
    assert @spare.stale?
  end

  test "stale? trips at twice the refresh interval" do
    @weather.update!(refresh_seconds: 900)

    @weather.update!(fetched_at: 25.minutes.ago)
    assert_not @weather.stale?

    @weather.update!(fetched_at: 35.minutes.ago)
    assert @weather.stale?
  end

  test "in_use? reports whether a dashboard item references it" do
    assert @weather.in_use?
    assert_not @spare.in_use?
  end

  test "refresh_seconds must be at least a minute" do
    @spare.refresh_seconds = 59
    assert_not @spare.valid?
    assert_includes @spare.errors.full_messages.to_sentence, "Refresh seconds"

    @spare.refresh_seconds = 60
    assert @spare.valid?
  end

  test "record_failure counts up and keeps the last good payload" do
    @weather.update!(payload: { "current" => { "temp" => 70 } })

    @weather.record_failure(StandardError.new("boom"))
    @weather.record_failure(StandardError.new("boom again"))

    assert_equal 2, @weather.failure_count
    assert_equal "boom again", @weather.last_error
    assert_equal 70, @weather.payload.dig("current", "temp")
  end

  test "record_success clears the failure state" do
    @weather.update!(failure_count: 3, last_error: "boom")
    @weather.record_success({ "current" => { "temp" => 71 } })

    assert_equal 0, @weather.failure_count
    assert_nil @weather.last_error
    assert_equal 71, @weather.payload.dig("current", "temp")
  end

  test "destroying a source destroys its provider" do
    assert_difference "RssProvider.count", -1 do
      @spare.destroy!
    end
  end

  test "due finds sources past their refresh interval" do
    Source.update_all(fetched_at: Time.current)
    @weather.update_columns(refresh_seconds: 900, fetched_at: 20.minutes.ago)

    assert_includes Source.due, @weather
    assert_not_includes Source.due, sources(:two)
  end

  test "provider_class covers every declared provider" do
    Source::PROVIDERS.each do |type|
      assert_equal type, Source.provider_class(type).name
    end

    assert_nil Source.provider_class("Kernel")
    assert_nil Source.provider_class(nil)
  end

  # --- the provider registry ---

  test "PROVIDERS is generated from app/models/providers" do
    on_disk = Rails.root.join("app/models/providers").glob("*.rb")
                  .map { |f| f.basename(".rb").to_s.camelize }.sort

    assert_equal on_disk, Source::PROVIDERS
    assert_operator Source::PROVIDERS.size, :>=, 3
  end

  test "every provider resolves to a class that includes Providable" do
    Source::PROVIDERS.each do |name|
      klass = Source.provider_class(name)

      assert_equal name, klass.name
      assert_includes klass.ancestors, Providable
      assert_operator klass, :<, ApplicationRecord
    end
  end

  # The registry is only as good as the declarations, so a provider that
  # forgets `provides` should fail here rather than in a form.
  test "every provider declares its label, attributes and refresh interval" do
    Source::PROVIDERS.each do |name|
      klass = Source.provider_class(name)

      assert klass.label.present?, "#{name} declares no label"
      assert klass.form_attributes.present?, "#{name} declares no form attributes"
      assert_operator klass.default_refresh_seconds.to_i, :>=, 60,
                      "#{name} declares no usable refresh interval"
      assert_kind_of Hash, klass.defaults
    end
  end

  test "declared form attributes are real columns" do
    Source::PROVIDERS.each do |name|
      klass = Source.provider_class(name)
      klass.form_attributes.each do |attribute|
        assert_includes klass.column_names, attribute.to_s,
                        "#{name} offers #{attribute}, which is not a column"
      end
    end
  end

  test "declared defaults only set attributes the form offers" do
    Source::PROVIDERS.each do |name|
      klass = Source.provider_class(name)
      assert_empty klass.defaults.keys.map(&:to_sym) - klass.form_attributes,
                   "#{name} defaults an attribute its form cannot edit"
    end
  end

  test "provider_class refuses anything not in the registry" do
    assert_nil Source.provider_class("Kernel")
    assert_nil Source.provider_class("ApplicationRecord")
    assert_nil Source.provider_class(nil)
    assert_nil Source.provider_class("")
  end

  test "provider_label falls back to the raw type for an unknown provider" do
    assert_equal "Weather", Source.provider_label("WeatherProvider")
    assert_equal "Nope", Source.provider_label("Nope")
  end

  test "each provider summarizes itself for the source list" do
    assert_equal "https://example.com/feed.xml", @spare.providable.detail
    assert_match(/47\.6062, -122\.3321/, @weather.providable.detail)
    assert_equal "https://example.com/calendar.ics", ical_providers(:one).detail
  end
end
