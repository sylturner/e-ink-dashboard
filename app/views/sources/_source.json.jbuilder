json.extract! source, :id, :name, :providable_id, :providable_type, :refresh_seconds, :payload, :fetched_at, :attempted_at, :last_error, :failure_count, :created_at, :updated_at
json.url source_url(source, format: :json)
