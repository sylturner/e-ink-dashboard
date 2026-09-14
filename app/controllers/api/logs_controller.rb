# POST /api/log
#
# The firmware's diagnostics -- wake reasons, Wi-Fi trouble, failed
# downloads -- written to the Rails log, tagged with the panel.
class Api::LogsController < Api::BaseController
  ERROR_LEVELS = %w[error fatal].freeze

  def create
    entries = Array.wrap(request.request_parameters["logs"]).grep(Hash)

    Rails.logger.tagged("TRMNL", current_device&.name || mac.presence || "unknown panel") do
      entries.each do |entry|
        level = entry["level"].to_s.in?(ERROR_LEVELS) ? :warn : :info
        Rails.logger.public_send(level, entry.to_json)
      end
    end

    head :no_content
  end
end
