# The phone page of a checklist (ChecklistProvider), and the controllers
# that change it. Unauthenticated like the rest of the app, and laid out
# for a phone rather than the admin.
module ChecklistScoped
  extend ActiveSupport::Concern

  included do
    layout "phone"

    before_action :set_checklist
  end

  private

    def set_checklist
      @checklist = ChecklistProvider.find(params[:checklist_id] || params.expect(:id))
    end

    # Changes the list and saves it, with the row locked so two phones
    # checking items off at once don't undo each other. Returns whether it
    # saved.
    def change_checklist
      @checklist.with_lock do
        yield @checklist
        @checklist.save
      end
    end

    # The list is edited on its phone page and on its source's edit page
    # (checklists/_editor), which sends back: "source". Each change goes
    # back to the page it came from.
    def from_source?
      params[:back] == "source"
    end

    def back_to_checklist(notice = nil)
      redirect_to from_source? ? edit_source_path(@checklist.source) : edit_checklist_path(@checklist),
                  notice:, status: :see_other
    end

    # The page the change came from, again, with what couldn't be saved.
    def rerender_checklist
      if from_source?
        @source = @checklist.source
        render "sources/edit", layout: "application", status: :unprocessable_content
      else
        render "checklists/edit", status: :unprocessable_content
      end
    end
end
