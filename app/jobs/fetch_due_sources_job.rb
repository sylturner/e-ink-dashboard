class FetchDueSourcesJob < ApplicationJob
  queue_as :default

  def perform
    Source.due.find_each { |source| FetchSourceJob.perform_later(source) }
  end
end
