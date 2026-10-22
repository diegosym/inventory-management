class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description, default: ''
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :stock, default: 0, null: false
      t.string :sku, null: false
      t.boolean :active, default: true, null: false

      t.timestamps

      t.index :sku, unique: true
    end
  end
end
