class CreateRkkKintai < ActiveRecord::Migration[7.2]
  def up
    create_table :rkk_kintai, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci' do |t|
      t.integer :user_id, null: false
      t.date :work_date, null: false
      t.string :start_time, null: false
      t.string :end_time, null: false
      t.string :work_attribute

      t.timestamps
    end

    add_index :rkk_kintai, [:user_id, :work_date], unique: true
  end

  def down
    drop_table :rkk_kintai
  end
end
