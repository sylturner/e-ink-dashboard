# Joins a panel to a dashboard it is allowed to show. A device can be
# assigned several; Device#dashboard is whichever one is on the panel now.
class DeviceDashboard < ApplicationRecord
  belongs_to :device
  belongs_to :dashboard

  validates :device_id, uniqueness: { scope: :dashboard_id }

  # Assignments are usually changed without touching the device row --
  # `device.dashboards = [...]`, or creating one of these directly -- so
  # the device's active dashboard is reconciled from this side too.
  after_save    :sync_device
  after_destroy :sync_device

  private

    def sync_device
      device&.sync_active_dashboard
    end
end
