# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

This is a freshly generated Rails 8.1 application (`rails new` defaults, service name `e_ink_dashboard`). There is no domain code yet — no models, controllers, routes, or migrations beyond the framework scaffolding. Expect to build features from scratch.

## Commands

- `bin/setup` — install dependencies, prepare the database, start the app (`bin/setup --skip-server` to skip the server).
- `bin/dev` — run the app locally (Puma via `Procfile.dev`).
- `bin/rails test` — run the full test suite (Minitest).
- `bin/rails test test/models/foo_test.rb` — run one file; append `:42` to run the test at line 42.
- `bin/rails test:system` — Capybara + Selenium system tests (not run in `bin/ci` by default).
- `bin/ci` — full local CI pipeline (see `config/ci.rb`): setup, RuboCop, bundler-audit, importmap audit, Brakeman, tests, seed replant.
- `bin/rubocop` — lint (rubocop-rails-omakase config in `.rubocop.yml`).
- `bin/brakeman` — static security analysis.
- `bin/rails db:prepare` / `bin/rails db:seed:replant` — set up or reseed the database.

CI (`.github/workflows/ci.yml`) runs Brakeman, bundler-audit, importmap audit, RuboCop, `test`, and `test:system` as separate jobs on every PR.

## Architecture

- **Rails 8.1**, Ruby 4.0.6, Puma. Server-rendered with Hotwire (Turbo + Stimulus).
- **No Node build step.** JavaScript is managed by `importmap-rails` (`config/importmap.rb`); Stimulus controllers live in `app/javascript/controllers/`. Assets are served by Propshaft.
- **SQLite for everything, across four databases in production** (`config/database.yml`): `primary`, plus dedicated `cache`, `queue`, and `cable` databases with separate migration paths (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`). Development/test use a single SQLite file each in `storage/`.
- **Solid adapters** back the framework: `solid_cache` (Rails.cache), `solid_queue` (Active Job), `solid_cable` (Action Cable). Jobs run inside the Puma process in production (`SOLID_QUEUE_IN_PUMA=true`); recurring jobs are defined in `config/recurring.yml`.
- **Deployment** is via Kamal (`config/deploy.yml`, `bin/kamal`) as a Docker container (`Dockerfile`), with `storage/` on a persistent volume so the SQLite databases and Active Storage files survive deploys. `thruster` fronts Puma for asset caching/compression.
- **Active Storage** is configured with `image_processing` (libvips) for variants.
