class AddDitherToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :dither, :string, default: "floyd_steinberg", null: false
  end
end
