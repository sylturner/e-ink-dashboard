class RendersController < ApplicationController
  layout "render"

  # GET /render/dashboard(?dashboard_id=N)
  #
  # The builder's preview iframe passes the dashboard it is editing.
  # Without it, fall back to whatever the first device is showing.
  def dashboard
    @dashboard = Dashboard.find_by(id: params[:dashboard_id])
    @device    = @dashboard ? @dashboard.devices.first : Device.first
    @dashboard ||= @device&.dashboard || Dashboard.first
    @items     = @dashboard&.dashboard_items&.visible
    # The panel's clock, as FrameComposer draws it.
    @now       = @device ? @device.local_time : Time.current
  end

  # POST /render/preview
  #
  # The builder posts its unsaved Dashboard settings and, when a tile is
  # open in the inspector, that tile's form. The dashboard is drawn with
  # them applied in memory: nothing is saved. Changes that couldn't be
  # saved draw the reasons instead.
  def preview
    @dashboard = Dashboard.find(params.expect(:dashboard_id))
    @dashboard.assign_attributes(params.expect(dashboard: Dashboard::FORM_ATTRIBUTES)) if params.key?(:dashboard)
    @device    = @dashboard.devices.first
    @now       = @device ? @device.local_time : Time.current
    draft      = draft_item if params.key?(:item_id)

    @errors = [ @dashboard, draft ].compact.flat_map { it.validate ? [] : it.errors.full_messages }
    return render :invalid, status: :unprocessable_content if @errors.any?

    # The draft stands in for its saved tile, and leaves the grid when
    # "Show on dashboard" is unchecked.
    @items = @dashboard.dashboard_items.map { draft && it.id == draft.id ? draft : it }.select(&:visible?)
    render :dashboard
  end

  private

    def draft_item
      @dashboard.dashboard_items.find(params.expect(:item_id))
                .draft(params.expect(dashboard_item: DashboardItem::FORM_ATTRIBUTES).except(:dashboard_id),
                       dashboard: @dashboard)
    end
end
