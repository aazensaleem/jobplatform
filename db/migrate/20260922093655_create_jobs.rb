class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :location
      t.string :job_type
      t.string :experience_level
      t.decimal :salary_min, precision: 12, scale: 2
      t.decimal :salary_max, precision: 12, scale: 2
      t.datetime :deadline
      t.string :status, null: false, default: "draft"
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end
  end
end
