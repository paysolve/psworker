class CreateAccounts < ActiveRecord::Migration[7.0]
  def change
    create_table :accounts do |t|
      #t.string :name
      t.string :account_identifier
      t.string :psmain_code
      t.string :institution
      #t.boolean :native
      #t.string :product_name
      t.string :bsb
      t.string :account_number
      t.string :account_name
      #t.string :email
      #t.string :main_payid
      t.datetime :last_executed_at
      t.string :last_identifier
      t.datetime :last_time
      #t.string :last_secondary_identifier
      #t.string :last_ps_identifier
      t.string :first_identifier
      #t.string :auth_ciphertext
      t.integer :total_transactions
      t.integer :total_transaction_value
      t.integer :last_block_transactions
      t.integer :last_block_value
      #t.string :username
      #t.string :password_ciphertext
      t.boolean :test_account

      t.string :consent_identifier
      t.string :connection_identifier
      t.datetime :consent_expires_at
      t.string :user_identifier
      t.string :psmain_account

      t.timestamps
    end
  end
end
