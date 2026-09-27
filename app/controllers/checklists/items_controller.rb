# Adds, checks off, moves and removes one item on a checklist's phone page.
module Checklists
  class ItemsController < ApplicationController
    include ChecklistScoped

    before_action :require_item, except: :create

    # POST /checklists/:checklist_id/items
    def create
      @item = ChecklistItem.new(params.expect(item: [ :text ]))

      if @item.valid? && change_checklist { it.add_item(@item.text) }
        back_to_checklist t("checklists.added", text: @item.text.squish)
      else
        @checklist.errors.each { @item.errors.add(:base, it.full_message) }
        @checklist.restore_attributes
        rerender_checklist
      end
    end

    # PATCH /checklists/:checklist_id/items/:id
    #
    # Sets whether it's done, rather than flipping it, so a form sent twice
    # (a double tap, a slow connection) leaves it as asked.
    def update
      done = params.expect(item: [ :done ])[:done] == "1"
      change_checklist { it.toggle_item(params[:id]) if done != it.done?(params[:id]) }
      back_to_checklist
    end

    # PATCH /checklists/:checklist_id/items/:id/move
    def move
      change_checklist { it.move_item(params[:id], params.expect(:by).to_i.clamp(-1, 1)) }
      back_to_checklist
    end

    # DELETE /checklists/:checklist_id/items/:id
    def destroy
      text = @checklist.entries.find { it.id == params[:id] }.text
      change_checklist { it.remove_item(params[:id]) }
      back_to_checklist t("checklists.removed", text:)
    end

    private

      def require_item
        head :not_found unless @checklist.item?(params[:id])
      end
  end
end
