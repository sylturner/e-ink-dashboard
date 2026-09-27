# A checklist's phone page: what the QR code on a checklist tile, or an
# NFC tag, opens. Its changes go to Checklists::ItemsController and
# Checklists::DoneItemsController, which come back here.
class ChecklistsController < ApplicationController
  include ChecklistScoped

  # GET /checklists/:id/edit
  def edit
    @item = ChecklistItem.new
  end
end
