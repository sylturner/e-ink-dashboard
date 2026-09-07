# Assigning a dashboard to a panel, from either side of the relationship.
class DeviceDashboardsController < ApplicationController
  def create
    @assignment = DeviceDashboard.new(assignment_params)

    if @assignment.save
      redirect_to return_path, notice: "#{@assignment.dashboard.name} assigned to #{@assignment.device.name}."
    else
      redirect_to return_path, alert: @assignment.errors.full_messages.to_sentence
    end
  end

  def destroy
    @assignment = DeviceDashboard.find(params.expect(:id))
    device, dashboard = @assignment.device, @assignment.dashboard
    @assignment.destroy

    redirect_to return_path(device:, dashboard:),
                notice: "#{dashboard.name} unassigned from #{device.name}.",
                status: :see_other
  end

  private

    def assignment_params
      params.expect(device_dashboard: [ :device_id, :dashboard_id ])
    end

    # Allowlisted rather than a redirect_to parameter, so this can never
    # be pointed somewhere else.
    def return_path(device: @assignment&.device, dashboard: @assignment&.dashboard)
      case params[:context]
      when "builder" then builder_dashboard_path(dashboard)
      when "devices" then devices_path
      else device_path(device)
      end
    end
end
