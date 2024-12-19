class AddStatusToAccount < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :status, :integer

    add_index :transfers, :code
    add_index :transfers, :identifier
    add_index :transfers, :posted_date
    add_index :transfers, :posted_datetime
    add_index :transfers, :psmain_code
  end
end

# add_index :accounts, :status
