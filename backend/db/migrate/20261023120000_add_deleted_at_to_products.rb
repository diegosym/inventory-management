# Spec 004 T1 (D-P31/D-P33): soft-delete storage. `deleted_at` NULL = visible,
# timestamp = soft-deleted. The plain index backs the visibility column; the SKU
# unique index becomes partial (`WHERE deleted_at IS NULL`) so a deleted
# product's SKU may be reused while visible SKUs stay unique (RF-4).
class AddDeletedAtToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :deleted_at, :datetime
    add_index :products, :deleted_at

    remove_index :products, :sku
    add_index :products, :sku,
              unique: true,
              where: 'deleted_at IS NULL',
              name: 'index_products_on_sku_visible'
  end
end
