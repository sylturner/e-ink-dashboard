class AddEnrollmentToDevices < ActiveRecord::Migration[8.1]
  def up
    add_column :devices, :mac_address, :string
    add_column :devices, :claim_code, :string
    add_column :devices, :enrolled_at, :datetime

    add_index :devices, :mac_address, unique: true
    add_index :devices, :claim_code, unique: true

    # Devices that predate enrollment still need a code: an unclaimed
    # panel shows one on its setup screen however the row got there.
    alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars
    taken = []

    select_values("SELECT id FROM devices WHERE claim_code IS NULL").each do |id|
      code = loop do
        candidate = Array.new(4) { alphabet.sample }.join
        break candidate unless taken.include?(candidate)
      end
      taken << code
      execute("UPDATE devices SET claim_code = #{quote(code)} WHERE id = #{id.to_i}")
    end
  end

  def down
    remove_index :devices, :claim_code
    remove_index :devices, :mac_address
    remove_column :devices, :enrolled_at
    remove_column :devices, :claim_code
    remove_column :devices, :mac_address
  end
end
