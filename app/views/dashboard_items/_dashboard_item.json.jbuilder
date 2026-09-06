json.extract! dashboard_item, :id, :dashboard_id, :kind, :view, :title, :col, :row, :col_span, :row_span, :position, :settings, :visible, :created_at, :updated_at
json.url dashboard_item_url(dashboard_item, format: :json)
