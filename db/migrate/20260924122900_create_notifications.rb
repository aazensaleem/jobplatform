class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.text :message, null: false
      t.datetime :read_at

      t.timestamps
    end
  end
end
