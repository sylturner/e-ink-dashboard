# The banner that opens a section's index page
# (application/_page_header.html.erb).
module PageHeaderHelper
  # Also titles the page, unless the view already has.
  #
  #   <%= page_header "Sources", icon: "cil-rss", description: "..." do %>
  #     <%= link_to "Add a source", new_source_path, class: "btn btn-light" %>
  #   <% end %>
  def page_header(title, icon:, description: nil, &actions)
    content_for :title, title unless content_for?(:title)

    render "application/page_header", title:, icon:, description:,
           actions: (capture(&actions) if actions)
  end
end
