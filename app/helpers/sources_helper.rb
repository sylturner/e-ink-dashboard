# How a source's fetching is going, for the source list and details page,
# and the choices its form offers.
module SourcesHelper
  # A weather source's units, on its form and as the app settings' default.
  def weather_units_options
    WeatherProvider::UNITS.map { [ t("weather.units.#{it}"), it ] }
  end

  # A badge -- OK, failing with its failure count, or not fetched yet --
  # followed by the last error while the source isn't healthy.
  def source_health(source)
    badge = if source.healthy?
      status_badge "OK", :success
    elsif source.failure_count.to_i.positive?
      status_badge pluralize(source.failure_count, "failure"), :danger
    else
      status_badge "Not fetched", :secondary
    end

    error = tag.div(source.last_error, class: "small text-app-danger mt-1") if source.last_error.present? && !source.healthy?
    safe_join([ badge, error ].compact)
  end
end
