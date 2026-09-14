# A note's phone page: what the QR code on a note tile, or an NFC tag,
# opens. Unauthenticated like the rest of the app, and laid out for a phone
# rather than the admin.
class NotesController < ApplicationController
  layout "note"

  before_action :set_note

  # GET /notes/:id/edit
  def edit
  end

  # PATCH/PUT /notes/:id
  def update
    if @note.update(note_params)
      redirect_to edit_note_path(@note), notice: t("notes.saved"), status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

    def set_note
      @note = NoteProvider.find(params.expect(:id))
    end

    def note_params
      params.expect(note: [ :body ])
    end
end
