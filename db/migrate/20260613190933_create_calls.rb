class CreateCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :calls do |t|
      t.references :campaign, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.integer :status, null: false
      t.datetime :ended_at
      t.string :call_number
      t.integer :duration_seconds

      t.timestamps

      t.index :started_at
    end
  end
end
