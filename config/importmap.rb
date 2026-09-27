# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
# Vendored from @coreui/coreui dist/js. The UMD bundle includes Popper and
# sets window.coreui when imported.
pin "@coreui/coreui", to: "coreui.bundle.min.js" # @5.9.0
# Active Storage's own client, from the gem: the Markdown editor's image
# uploads (markdown_editor_controller.js).
pin "@rails/activestorage", to: "activestorage.esm.js"
pin_all_from "app/javascript/controllers", under: "controllers"
