class CreateDisbursements < ActiveRecord::Migration[7.0]
  def change
    create_table :disbursements do |t|
      t.integer :total_amount
      t.integer :status
      t.string :code
      t.references :account, foreign_key: true
      t.datetime :executed_at

      t.timestamps
    end
    add_column :accounts, :outlay_auth_ciphertext, :string
    add_column :accounts, :outlay_username, :string
    add_column :accounts, :outlay_name, :string
    add_column :accounts, :outlay_password_ciphertext, :string

    add_index :accounts, [:bsb, :account_number]
    add_index :accounts, :psmain_code
    add_index :accounts, :consent_identifier
    add_index :accounts, :account_identifier

  end
end
