namespace :fonts do
  desc "Write the admin font picker's previews (app/assets/stylesheets/font_previews.css) from NewspaperFont"
  task previews: :environment do
    path = Rails.root.join("app/assets/stylesheets/font_previews.css")
    File.write(path, NewspaperFont.preview_css)
    puts "Wrote #{path.relative_path_from(Rails.root)}"
  end
end
