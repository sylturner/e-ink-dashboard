class AddIcsUploadToIcalProviders < ActiveRecord::Migration[8.1]
  def change
    # Raw .ics text for calendars uploaded as a file rather than
    # subscribed by URL. Encrypted at rest like ical_url, since the
    # contents are as sensitive as the address that hands them out.
    add_column :ical_providers, :ics_data, :text
    add_column :ical_providers, :ics_filename, :string
  end
end
