# How a source's fetching is going, for the source list and details page.
module SourcesHelper
  # When the source last fetched successfully, in words, with the exact
  # time in the <time> element's datetime.
  def source_fetched_ago(source)
    return "Never" if source.fetched_at.nil?

    tag.time "#{time_ago_in_words(source.fetched_at)} ago", datetime: source.fetched_at.iso8601
  end

  # A badge -- OK, failing with its failure count, or not fetched yet --
  # followed by the last error while the source isn't healthy.
  def source_health(source)
    badge = if source.healthy?
      tag.span "OK", class: "badge bg-success-subtle text-success-emphasis"
    elsif source.failure_count.to_i.positive?
      tag.span pluralize(source.failure_count, "failure"), class: "badge bg-danger-subtle text-danger-emphasis"
    else
      tag.span "Not fetched", class: "badge bg-secondary-subtle text-secondary-emphasis"
    end

    error = tag.div(source.last_error, class: "small text-app-danger mt-1") if source.last_error.present? && !source.healthy?
    safe_join([ badge, error ].compact)
  end
end
