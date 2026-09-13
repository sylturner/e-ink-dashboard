class DashboardsController < ApplicationController
  before_action :set_dashboard, only: %i[ edit update destroy ]

  # GET /dashboards
  def index
    # Each card sizes its thumbnail from the devices and describes it
    # from the tiles.
    @dashboards = Dashboard.includes(:devices, :dashboard_items)
  end

  # GET /dashboards/new
  #
  # The builder before there is a dashboard: tiles can only be added once
  # it is saved, so only its settings can be filled in.
  def new
    @dashboard = Dashboard.new
  end

  # GET /dashboards/1/edit
  #
  # The builder.
  def edit
    load_builder
  end

  # POST /dashboards
  def create
    @dashboard = Dashboard.new(dashboard_params)

    if @dashboard.save
      redirect_to edit_dashboard_path(@dashboard), notice: "#{@dashboard.name} was created. Add some tiles to it."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /dashboards/1
  def update
    if @dashboard.update(dashboard_params)
      redirect_to edit_dashboard_path(@dashboard), notice: "Dashboard settings saved.", status: :see_other
    else
      load_builder
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /dashboards/1
  def destroy
    @dashboard.destroy!

    redirect_to dashboards_path, notice: "#{@dashboard.name} was deleted.", status: :see_other
  end

  private
    def set_dashboard
      @dashboard = Dashboard.find(params.expect(:id))
    end

    def load_builder
      @items   = @dashboard.dashboard_items.order(:position)
      @sources = Source.order(:name)
      @devices = @dashboard.devices.order(:name)
      @assignments = @dashboard.device_dashboards.index_by(&:device_id)
      @assignable_devices = Device.where.not(id: @devices.map(&:id)).order(:name)
    end

    def dashboard_params
      params.expect(dashboard: [ :name, :theme, :grid_columns, :grid_rows ])
    end
end
