require "test_helper"

class ComponentTest < ActiveSupport::TestCase
  test "every kind declares a label, at least one view, and a settings list" do
    Component::KINDS.each do |kind|
      assert Component.label(kind).present?, "#{kind} has no label"
      assert Component.views(kind).any?, "#{kind} has no views"
      assert_kind_of Array, Component.settings(kind)
    end
  end

  test "every declared source type is a real provider" do
    Component::KINDS.each do |kind|
      Component.source_types(kind).each do |type|
        assert_includes Source::PROVIDERS, type, "#{kind} wants unknown #{type}"
      end
    end
  end

  test "a setting's views only name layouts the kind actually offers" do
    Component::KINDS.each do |kind|
      views = Component.views(kind).keys
      Component.settings(kind).each do |setting|
        Array(setting.views).each do |view|
          assert_includes views, view, "#{kind}/#{setting.key} names unknown view #{view}"
        end
      end
    end
  end

  test "default_view is the first declared layout" do
    assert_equal "today", Component.default_view("calendar")
    assert_equal "current", Component.default_view("weather")
    assert_nil Component.default_view("nope")
  end

  test "settings filter down to the ones a layout uses" do
    keys = Component.settings("calendar", view: "next_days").map(&:key)
    assert_includes keys, "day_count"
    assert_includes keys, "show_times"
    assert_not_includes keys, "event_limit"

    assert_equal %w[event_limit show_times],
                 Component.settings("calendar", view: "today").map(&:key)
  end

  test "settings with no declared views apply to every layout" do
    assert_equal Component.settings("news").map(&:key),
                 Component.settings("news", view: "headlines").map(&:key)
  end

  test "multi_source? distinguishes combinable kinds" do
    assert Component.multi_source?("calendar")
    assert Component.multi_source?("news")
    assert_not Component.multi_source?("weather")
    assert_not Component.multi_source?("clock")
  end

  test "an unknown kind answers safely everywhere" do
    assert_equal({}, Component.views("nope"))
    assert_equal [], Component.settings("nope")
    assert_equal [], Component.source_types("nope")
    assert_not Component.multi_source?("nope")
  end

  test "casting turns form strings back into the declared type" do
    integer = Component.setting("calendar", "day_count")
    assert_equal 7, integer.cast("7")
    assert_equal 3, integer.cast(""), "blank falls back to the default"
    assert_equal 3, integer.cast(nil)

    boolean = Component.setting("calendar", "show_times")
    assert_equal true,  boolean.cast("1")
    assert_equal false, boolean.cast("0")
    assert_equal true,  boolean.cast(nil), "nil falls back to the default"
  end
end
