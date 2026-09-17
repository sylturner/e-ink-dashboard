# The headline template's fields (news_templates/_fields), in the tile
# inspector and on the Settings page.
module NewsTemplatesHelper
  # Paths a feed carries beyond the named tokens, listed under a custom
  # line so they can be found without reading the feed's XML.
  FIELD_PATH_LIMIT = 40

  def news_template_field_options
    [ NewsTemplate::NONE, *NewsTemplate::FIELDS, NewsTemplate::CUSTOM ].map do
      [ t("news_templates.fields.#{it}"), it ]
    end
  end

  def news_template_placement_options
    NewsTemplate::PLACEMENTS.map { [ t("news_templates.placements.#{it}"), it ] }
  end

  def news_template_image_size_options
    NewsTemplate::IMAGE_SIDES.keys.map { [ t("components.sizes.#{it}"), it ] }
  end

  def news_template_line_size_options
    NewsTemplate::LINE_SIZES.keys.map { [ t("components.sizes.#{it}"), it ] }
  end

  # Every field path in the sources' items, most common first. A named
  # token's own element ({title}) is left out, being listed already.
  def feed_field_paths(sources)
    counts = sources.flat_map { |source| Array(source.payload&.dig("items")) }
                    .grep(Hash)
                    .flat_map { it["fields"].is_a?(Hash) ? it["fields"].keys : [] }
                    .tally

    counts.except(*NewsTemplate::FIELDS)
          .sort_by { |path, count| [ -count, path ] }
          .first(FIELD_PATH_LIMIT)
          .map(&:first)
  end
end
