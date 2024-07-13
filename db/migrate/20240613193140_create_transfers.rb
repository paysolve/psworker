class CreateTransfers < ActiveRecord::Migration[7.0]
  def change
    create_table :transfers do |t|
      t.string :code
      t.string :identifier
      t.string :posted_date
      t.datetime :posted_datetime
      t.string :connection_identifier
      t.references :account, null: false, foreign_key: true
      t.string :data_digest
      t.string :psmain_code
      t.string :reference

      t.timestamps
    end
  end
end

# add_index :transfers, :code
# add_index :transfers, :identifier
# add_index :transfers, :posted_date
# add_index :transfers, :posted_datetime=
# add_index :transfers, :psmain_code
