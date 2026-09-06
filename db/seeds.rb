dashboard = Dashboard.find_or_create_by!(name: "Kitchen") do |d|
  d.theme = "default"
  d.grid_columns = 8
  d.grid_rows = 8
end

device = Device.find_or_create_by!(name: "Kitchen panel") do |dev|
  dev.dashboard = dashboard
  dev.width = 800
  dev.height = 480
  dev.bit_depth = 1
  dev.image_format = "bmp"
  dev.refresh_seconds = 300
  dev.night_refresh_seconds = 3600
  dev.active_from_hour = 6
  dev.active_until_hour = 23
  dev.time_zone = "America/New_York"
end

weather = Source.find_or_create_by!(name: "Home weather") do |s|
  s.providable = WeatherProvider.new(
    latitude: 33.8109, longitude: -84.2397,
    units: "imperial", time_zone: "America/New_York"
  )
  s.refresh_seconds = 900
end

news = Source.find_or_create_by!(name: "AP Top News") do |s|
  s.providable = RssProvider.new(
    feed_url: "https://feeds.apnews.com/rss/apf-topnews",
    max_items: 10
  )
  s.refresh_seconds = 1800
end

items = [
  { kind: "clock", title: nil, col: 1, row: 1, col_span: 3, row_span: 3 },
  { kind: "calendar", title: "Today", col: 4, row: 1, col_span: 5, row_span: 3 },
  { kind: "weather", title: "Weather", col: 1, row: 4, col_span: 3, row_span: 3,
    source: weather },
  { kind: "news", title: "Headlines", col: 4, row: 4, col_span: 5, row_span: 3,
    source: news },
  { kind: "text", title: nil, col: 1, row: 7, col_span: 8, row_span: 2,
    settings: { "body" => "Phase 2 wiring check" } }
]

items.each_with_index do |attrs, i|
  source = attrs.delete(:source)
  item = dashboard.dashboard_items.find_or_create_by!(
    kind: attrs[:kind], col: attrs[:col], row: attrs[:row]
  ) do |it|
    it.assign_attributes(attrs.merge(position: i, visible: true))
  end
  item.sources << source if source && item.sources.exclude?(source)
end

puts "Device token: #{device.token}"
