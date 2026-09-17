# A strip along the foot of the panel naming the dashboard it shows, the
# ones either side of it, and where it is among them. For panels with a
# dial or buttons to step through their dashboards; off for the rest.
class AddShowNavigationToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :show_navigation, :boolean, default: false, null: false
  end
end
