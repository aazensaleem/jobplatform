class AddEmployerApprovalToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :employer_approval_status, :string
    add_column :users, :employer_decided_at, :datetime

    execute <<~SQL
      UPDATE users
      SET employer_approval_status = 'approved', employer_decided_at = UTC_TIMESTAMP()
      WHERE role = 'employer'
    SQL
  end

  def down
    remove_column :users, :employer_decided_at
    remove_column :users, :employer_approval_status
  end
end
