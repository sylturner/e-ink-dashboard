require "test_helper"

# The layout shared by every admin page: navigation, landmarks, the app
# name and the default form builder. The e-ink render has its own layout
# (see RendersControllerTest).
class AdminLayoutTest < ActionDispatch::IntegrationTest
  test "the sidebar highlights the section being viewed" do
    get dashboards_url

    assert_select "#sidebar a.nav-link.active", 1
    assert_select "#sidebar a.nav-link.active[href=?]", dashboards_path
  end

  test "the builder counts as the Dashboards section" do
    get builder_dashboard_url(dashboards(:one))

    assert_select "#sidebar a.nav-link.active[href=?]", dashboards_path
  end

  # WCAG 3.1.1, 2.4.1 and 1.3.1: page language, a way past the repeated
  # sidebar, and landmarks for the navigation and content.
  test "the layout declares its language, landmarks and a skip link" do
    get dashboards_url

    assert_select "html[lang=en]"
    assert_select "body > a.skip-link[href=?]", "#main-content"
    assert_select "nav#sidebar[aria-label]"
    assert_select "main#main-content", 1
    assert_select "main#main-content h1", "Dashboards"
  end

  # WCAG 4.1.3: a notice waits for the reader; an alert interrupts.
  test "a notice is a status message" do
    patch dashboard_url(dashboards(:one)), params: { dashboard: { name: "Renamed" } }
    follow_redirect!

    assert_select ".alert.alert-success[role=status]"
    assert_select ".alert[role=alert]", 0
  end

  test "the app name comes from the locale file" do
    get dashboards_url

    assert_select "meta[name=application-name][content=?]", I18n.t("app.name")
    assert_select "#sidebar .sidebar-brand-full", I18n.t("app.name")
  end

  test "forms are styled by the admin form builder" do
    get new_dashboard_url

    assert_select "input.form-control[name=?]", "dashboard[name]"
    assert_select "input[type=submit].btn.btn-primary"
  end
end
