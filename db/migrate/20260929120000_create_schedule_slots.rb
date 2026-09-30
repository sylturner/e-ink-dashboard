# A panel's schedule: times of the week when one of its dashboards goes
# on it by itself (DashboardSchedule). A slot belongs to an assignment, so
# unassigning a dashboard takes its times with it.
#
# On the device, the dashboard it shows between them, and which stretch
# of the schedule it last put on the panel: a switch by hand holds until
# a new one begins.
class CreateScheduleSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_slots do |t|
      t.references :device_dashboard, null: false, foreign_key: true
      # Days of the week it starts on, 0 for Sunday, as Date#wday counts.
      t.json :days, null: false, default: []
      # Minutes after midnight. An end at or before the start is the next day.
      t.integer :from_minute, null: false
      t.integer :until_minute, null: false
      t.timestamps
    end

    add_reference :devices, :default_dashboard, foreign_key: { to_table: :dashboards }
    add_column :devices, :schedule_cue, :string
  end
end
