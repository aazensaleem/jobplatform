class AddJobAlertPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :job_alerts_enabled, :boolean, default: false, null: false
    add_column :users, :alert_location, :string
    add_column :users, :alert_job_type, :string
    add_column :users, :alert_experience_level, :string
    add_column :users, :last_job_alerted_at, :datetime
  end
end
