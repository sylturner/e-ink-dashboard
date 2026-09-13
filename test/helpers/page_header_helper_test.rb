require "test_helper"

class PageHeaderHelperTest < ActionView::TestCase
  test "renders the title, icon, description and actions, and titles the page" do
    @rendered = page_header("Sources", icon: "cil-rss", description: "Where the data comes from.") do
      link_to "Add a source", "/sources/new", class: "btn btn-light"
    end

    assert_select "header.page-hero" do
      assert_select "h1", "Sources"
      assert_select "svg[aria-hidden=true] use[href$=?]", "#cil-rss"
      assert_select "p", "Where the data comes from."
      assert_select "a.btn[href=?]", "/sources/new", "Add a source"
    end
    assert_equal "Sources", content_for(:title)
  end

  test "leaves out the description and actions when there are none" do
    @rendered = page_header("Devices", icon: "cil-devices")

    assert_select "header.page-hero h1", "Devices"
    assert_select "header.page-hero p", 0
    assert_select "header.page-hero .gap-2", 0
  end

  test "a page title links back to its section and titles the page" do
    @rendered = page_title("Kitchen", parent: [ "Dashboards", "/dashboards" ], crumb: "Builder")

    assert_select "nav[aria-label=Breadcrumb] .breadcrumb-item a[href=?]", "/dashboards", "Dashboards"
    assert_select ".breadcrumb-item.active[aria-current=page]", "Builder"
    assert_select "h1", "Kitchen"
    assert_equal "Kitchen", content_for(:title)
  end

  test "keeps a title the view already set" do
    content_for :title, "Kitchen settings"

    page_header("Dashboards", icon: "cil-speedometer")

    assert_equal "Kitchen settings", content_for(:title)
  end
end
