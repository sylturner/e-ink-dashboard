class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Fetches and renders read times and weeks as requests do.
  around_perform { |_job, block| AppSetting.current.apply(&block) }
end
