# State for one request or job. Rails resets it between them.
class Current < ActiveSupport::CurrentAttributes
  attribute :app_setting
end
