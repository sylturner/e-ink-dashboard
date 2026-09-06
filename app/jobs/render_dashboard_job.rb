class RenderDashboardJob < ApplicationJob
  queue_as :default

  def perform(device)
    FrameComposer.call(device)
  end
end
