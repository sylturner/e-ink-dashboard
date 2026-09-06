# Wired but inert until providers implement fetch! in Phase 3.
class FetchSourceJob < ApplicationJob
  queue_as :default

  def perform(source)
    source.record_success(source.providable.fetch!)
  rescue NotImplementedError
    Rails.logger.info("[Fetch] #{source.providable_type} not implemented yet")
  rescue StandardError => e
    source.record_failure(e)
    raise
  end
end
