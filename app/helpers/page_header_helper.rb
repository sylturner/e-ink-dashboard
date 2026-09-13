# The headings that open admin pages: the banner on a section's index
# (application/_page_header.html.erb) and the breadcrumb heading on the
# pages inside it (application/_page_title.html.erb). Both also title the
# page, unless the view already has.
module PageHeaderHelper
  #   <%= page_header "Sources", icon: "cil-rss", description: "..." do %>
  #     <%= link_to "Add a source", new_source_path, class: "btn btn-light" %>
  #   <% end %>
  def page_header(title, icon:, description: nil, &actions)
    content_for :title, title unless content_for?(:title)

    render "application/page_header", title:, icon:, description:,
           actions: (capture(&actions) if actions)
  end

  #   <%= page_title @source.name, parent: [ "Sources", sources_path ], crumb: "Edit" %>
  def page_title(title, parent:, crumb:)
    content_for :title, title unless content_for?(:title)

    render "application/page_title", title:, parent:, crumb:
  end
end
