class FetchSourceJob < ApplicationJob
  queue_as :default

  def perform(source)
    before = checksum(source.payload)
    source.record_success(source.providable.fetch!)

    enqueue_renders(source) if checksum(source.payload) != before
  # NotImplementedError descends from ScriptError rather than
  # StandardError, so a provider that has no fetch! yet (IcalProvider,
  # until Phase 6) has to be named explicitly or the job crash-loops.
  rescue NotImplementedError, StandardError => e
    source.record_failure(e)
    Rails.logger.warn("[Fetch] #{source.name}: #{e.class}: #{e.message}")
  end

  private

  def checksum(payload)
    Digest::SHA256.hexdigest(payload.to_json)
  end

  def enqueue_renders(source)
    Device.joins(dashboard: { dashboard_items: :dashboard_item_sources })
          .where(dashboard_item_sources: { source_id: source.id })
          .distinct
          .find_each { |device| RenderDashboardJob.perform_later(device) }
  end
end
