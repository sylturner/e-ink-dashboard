# A line of text with {tokens} in it, filled from whatever a template
# draws from: a news item (NewsTemplate), a JSON source's data
# (DataTemplate). Each token's name is handed to the block, which returns
# its value.
#
# A line whose tokens all come out empty is nil rather than its bare
# separators ("The Paper · " or " · 2h"), so it isn't drawn.
module TokenLine
  TOKEN = /\{([^{}\s]+)\}/

  # What a line's leftover separators look like once its tokens are
  # empty.
  DANGLING = /\A[\s·•|,\-–—]+|[\s·•|,\-–—]+\z/

  def self.fill(format)
    resolved = false

    text = format.to_s.gsub(TOKEN) do
      value = yield(::Regexp.last_match(1)).to_s
      resolved ||= value.present?
      value
    end

    text.gsub(DANGLING, "").squish.presence if resolved
  end
end
