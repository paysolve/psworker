class CreateOutlays < ActiveRecord::Migration[7.0]
  def change
    create_table :outlays do |t|
      t.integer :amount
      t.string :bsb
      t.string :code # perhaps include an idempotent code too?
      t.string :account_name
      t.string :account_number
      t.references :disbursement, foreign_key: true
      t.integer :status
      t.integer :purpose
      t.integer :payment_type
      t.string :note
      t.datetime :executed_at

      t.timestamps
    end

    add_index :disbursements, [:status, :executed_at]
    add_index :disbursements, :created_at
    add_index :disbursements, :code

  end
end

# remove_index :outlays, :disbursement_id
# add_index :outlays, [:disbursement_id, :status]
