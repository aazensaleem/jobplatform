class CreateApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :job, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.text :cover_letter

      t.timestamps
    end

    add_index :applications, %i[user_id job_id], unique: true
  end
end
