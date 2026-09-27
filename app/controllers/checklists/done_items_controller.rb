# Clears the checked items off a checklist's phone page.
module Checklists
  class DoneItemsController < ApplicationController
    include ChecklistScoped

    # DELETE /checklists/:checklist_id/done_items
    def destroy
      count = @checklist.items.size
      change_checklist(&:clear_done)
      back_to_checklist t("checklists.cleared", count: count - @checklist.items.size)
    end
  end
end
