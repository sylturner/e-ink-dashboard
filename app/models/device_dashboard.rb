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

    # A panel drawing the navigation strip names its dashboards, so the
    # frame on it is out of date too.
    def sync_device
      return if device.nil?

      device.sync_active_dashboard
      device.request_refresh! if device.show_navigation?
    end
end
