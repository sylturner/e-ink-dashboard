# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Keep this file current.** When a change makes anything here inaccurate, update this file in the same change. That includes adding, removing or renaming a model, provider, job, endpoint, command, directory or convention. If you notice something here is already out of date, fix it or tell the user.

## Status

A self-hosted server for ESP32 e-paper panels.
- It fetches data from sources (weather, iCal calendars, RSS feeds), lays it out on grid-based dashboards, and renders each dashboard to a 1-bit bitmap for the panels it is assigned to.
- A server-rendered admin UI manages all of this.
- It runs on a home LAN and has no authentication.

- **Domain** (`app/models`):
  - `Source` holds fetched data. Its type-specific settings and `fetch!` live in a provider in `app/models/providers` (`WeatherProvider`, `IcalProvider`, `RssProvider`). Providers are discovered from that directory through the `Providable` concern, so adding a provider means adding a file.
  - `Dashboard` is a grid (columns × rows, plus a theme) of `DashboardItem`s. Each item is a component (clock, calendar, weather, news, text) placed on the grid and fed by one or more sources. `Component` is the registry of each component's layouts, accepted source types and settings.
  - `Device` is a panel: size, bit depth, image format, dithering, refresh schedule and last-reported telemetry. `DeviceDashboard` assigns dashboards to devices. `Frame` stores rendered bitmaps.
- **Data refresh** (`config/recurring.yml`):
  - `FetchDueSourcesJob` runs every minute and queues a `FetchSourceJob` per due source. That job queues re-renders when a source's payload changes.
  - `RenderAllDevicesJob` re-renders every assigned panel every 30 minutes.
- **Render pipeline:**
  - `FrameComposer` renders `renders/dashboard` inside `layouts/render.html.erb`, whose only stylesheet is `render.css` (inlined by `InlineAssets`).
  - It screenshots the page in headless Chrome (`lib/browser_pool.rb`, via Ferrum) and converts the PNG to the device's format with `Bitmap` and `Dither`.
  - `GET /render/dashboard` serves the same HTML, which the builder's preview iframe shows.
  - `DashboardThumbnail` captures the same page, undithered, for the dashboard list (`GET /dashboards/:id/thumbnail.png`). Captures are cached under a digest of the HTML, which is also the ETag.
  - **Admin styling must never reach the render.** Don't add `render.css` to the admin layout, or admin CSS or JS to the render layout. After admin UI work, check that the `/render/dashboard` HTML is unchanged.
- **Device API.** It is used by the firmware in `esp32/esp32_dashboard/` and is deliberately unauthenticated.
  - `POST /devices/enroll` gives a panel a token for its MAC, plus a claim code shown on its screen until it is assigned a dashboard.
  - `GET /devices/:token/frame` returns the bitmap, composing a fresh one when it is due or forced. It also records telemetry from `X-*` headers and sets `Refresh-Rate`.
- **Admin UI:** Dashboards, Sources and Devices.
  - A dashboard has no show page. The list's cards show it, and the drag-and-drop builder (`grid_controller.js`) is both its new and edit page.
  - It is built on the vendored CoreUI 5.9 Bootstrap admin template (`vendor/assets`, `vendor/javascript`), with `AdminFormBuilder` as the default form builder.
  - Section index pages open with the `page_header` helper's banner (`application/_page_header.html.erb`).
  - It is being restyled one area at a time, so some views are still Rails scaffold.
- **Tests:** Minitest tests for models, services, controllers, a helper, the form builder and admin-layout integration. The jobs and mailers have no tests. There are no system tests either: `test/system` doesn't exist, though CI still runs `test:system`.
- `public/ditherer.html` is a standalone dithering tool, separate from the Rails app.

## Commands

- `bin/setup` — install dependencies, prepare the database, start the app (`bin/setup --skip-server` to skip the server).
- `bin/dev` — run the app locally (runs `bin/rails server`).
- `bin/rails test` — run the full test suite (Minitest).
- `bin/rails test test/models/foo_test.rb` — run one file; append `:42` to run the test at line 42.
- `bin/rails test:system` — Capybara + Selenium system tests (none exist yet; not run in `bin/ci` by default).
- `bin/ci` — full local CI pipeline (see `config/ci.rb`): setup, RuboCop, bundler-audit, importmap audit, Brakeman, tests, seed replant.
- `bin/rubocop` — lint (rubocop-rails-omakase config in `.rubocop.yml`).
- `bin/brakeman` — static security analysis.
- `bin/rails db:prepare` / `bin/rails db:seed:replant` — set up or reseed the database.

CI (`.github/workflows/ci.yml`) runs Brakeman, bundler-audit, importmap audit, RuboCop, `test`, and `test:system` as separate jobs on every PR.

## Conventions

- **Accessibility: WCAG 2.2 AA.** Every admin page must meet WCAG 2.2 AA in both the light and dark themes:
  - text contrast ≥ 4.5:1; focus indicators and control boundaries ≥ 3:1
  - everything keyboard-operable, with a single-click alternative to any drag
  - labeled controls, landmarks, status messages in live regions
  - reflow at 320px without the page scrolling sideways

  Reuse the tokens and components in `app/assets/stylesheets/application.css` (`--app-focus-ring`, `--app-control-border`, the `--app-*-on-light`/`-on-dark` colors, `.btn-app-outline`) instead of CoreUI defaults, several of which fail contrast. Verify in a real browser (e.g. axe-core in headless Chrome via Ferrum), not only by reading CSS. The e-ink render (`layouts/render.html.erb`, `render.css`) is a 1-bit panel image and is out of scope.
- **DRY.** Before adding something, look for an existing helper, partial, `AdminFormBuilder` method, Stimulus controller or CSS token, and reuse it. When something repeats, extract it: markup into partials or helpers, form styling into `AdminFormBuilder`, colors into CSS custom properties, user-facing strings into `config/locales`. Keep duplication only for a concrete reason, stated in a comment (e.g. the inline color-mode script that must run before first paint).
- **Rails 8 conventions.**
  - Use current framework idioms: `params.expect`, the Rails 8 helper names (`textarea`, `checkbox`), `tag`/`class_names` over string-building, I18n for copy.
  - In Stimulus, use targets, values and params, plus action filters and options (`keydown.enter->grid#pick:prevent`), rather than hand-written event handling.
  - Stay on importmap and Propshaft, with no Node build.
  - Keep pages CSP-ready: no inline event handlers or `style` attributes, and `javascript_tag nonce: true` for any inline script that can't be avoided.
  - Tests mirror `app/` (`app/form_builders` → `test/form_builders`); layout-wide behavior goes in `test/integration`.
- **American English** in comments, UI text, commit messages and docs: color, behavior, gray, center, initialize, labeled, enroll.

## Architecture

- **Rails 8.1**, Ruby 4.0.6, Puma. Server-rendered with Hotwire (Turbo + Stimulus).
- **No Node build step.** JavaScript is managed by `importmap-rails` (`config/importmap.rb`); Stimulus controllers live in `app/javascript/controllers/`. Assets are served by Propshaft.
- **SQLite for everything, across four databases in production** (`config/database.yml`): `primary`, plus dedicated `cache`, `queue`, and `cable` databases with separate migration paths (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`). Development/test use a single SQLite file each in `storage/`.
- **Solid adapters** back the framework: `solid_cache` (Rails.cache), `solid_queue` (Active Job), `solid_cable` (Action Cable). Jobs run inside the Puma process in production (`SOLID_QUEUE_IN_PUMA=true`); recurring jobs are defined in `config/recurring.yml`.
- **Headless Chrome** is a runtime dependency of the render pipeline (Ferrum). The Docker image installs Chromium and points `CHROME_PATH` at it; locally Ferrum finds an installed Chrome.
- **Deployment** is via Kamal (`config/deploy.yml`, `bin/kamal`) as a Docker container (`Dockerfile`), with `storage/` on a persistent volume so the SQLite databases and Active Storage files survive deploys. `thruster` fronts Puma for asset caching/compression.
- **Active Storage** is configured with `image_processing` (libvips) for variants.
