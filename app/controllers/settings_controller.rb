# The app's settings (AppSetting). There is one row, so a singular
# resource with only an edit page.
class SettingsController < ApplicationController
  before_action :set_setting

  # GET /settings/edit
  def edit
  end

  # PATCH/PUT /settings
  def update
    if @setting.update(setting_params)
      # A frame is only composed when one is due, so without this a new
      # zone, clock or server address would wait for the next scheduled
      # render.
      Device.claimed.update_all(refresh_requested_at: Time.current) if @setting.frame_settings_changed?

      redirect_to edit_settings_path, notice: "Settings were saved.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

    def set_setting
      @setting = AppSetting.current
    end

    def setting_params
      params.expect(app_setting: [ :time_zone, :clock, :week_start, :units, :server_url,
                                   *CheckInSchedule::SCHEDULE_ATTRIBUTES ])
    end
end
