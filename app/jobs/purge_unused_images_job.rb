# Clears out images uploaded through the Markdown editor that no note or
# text tile refers to any more (MarkdownImages). Daily, from
# config/recurring.yml.
class PurgeUnusedImagesJob < ApplicationJob
  queue_as :default

  def perform
    purged = MarkdownImages.purge_unused
    Rails.logger.info("Purged #{purged} unused #{"image".pluralize(purged)}") if purged.positive?
  end
end
