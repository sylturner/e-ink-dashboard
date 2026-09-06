class RenderAllDevicesJob < ApplicationJob
  queue_as :default

  def perform
    Device.where.not(dashboard_id: nil).find_each do |device|
      RenderDashboardJob.perform_later(device)
    end
  end
end
