class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.string :source, null: false
      t.string :name, null: false
      t.string :tracking_number, null: false

      t.timestamps
    end

    add_index :campaigns, "lower(name)", unique: true, name: "index_campaigns_on_lower_name"
    add_index :campaigns, :tracking_number, unique: true
  end
end
