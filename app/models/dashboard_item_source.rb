class DashboardItemSource < ApplicationRecord
  belongs_to :dashboard_item
  belongs_to :source
end
