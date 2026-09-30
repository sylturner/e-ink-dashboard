# The times of the week a panel's dashboards go on it by themselves
# (DashboardSchedule). They're listed on the device's page, which each of
# these returns to. A change reaches the panel when it next checks in.
class Devices::ScheduleSlotsController < ApplicationController
  before_action :set_device
  before_action :set_slot, only: %i[edit update destroy]

  # GET /devices/1/schedule_slots/new
  def new
    @slot = ScheduleSlot.new(days: ScheduleSlot::DAYS.to_a, device_dashboard: @device.device_dashboards.first)
  end

  # POST /devices/1/schedule_slots
  def create
    @slot = ScheduleSlot.new(slot_params)

    if @slot.save
      redirect_to edit_device_path(@device), notice: t(".notice", dashboard: @slot.dashboard.name), status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  # GET /devices/1/schedule_slots/1/edit
  def edit
  end

  # PATCH/PUT /devices/1/schedule_slots/1
  def update
    if @slot.update(slot_params)
      redirect_to edit_device_path(@device), notice: t(".notice", dashboard: @slot.dashboard.name), status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /devices/1/schedule_slots/1
  def destroy
    @slot.destroy!

    redirect_to edit_device_path(@device), notice: t(".notice", dashboard: @slot.dashboard.name), status: :see_other
  end

  private

    def set_device
      @device = Device.find(params.expect(:device_id))
    end

    def set_slot
      @slot = @device.schedule_slots.find(params.expect(:id))
    end

    # The dashboard is one of this panel's own, or none, which fails
    # validation.
    def slot_params
      attributes = params.expect(schedule_slot: ScheduleSlot::FORM_ATTRIBUTES)
      attributes.merge(device_dashboard: @device.device_dashboards.find_by(id: attributes.delete(:device_dashboard_id)))
    end
end
