# Spec 004 T3 (D-P36): the internal change-audit table — one row per
# successful product change. Write-once record: `created_at` only (no
# `updated_at`), a plain `product_id` with no foreign key (the audit must
# outlive any future purge), no polymorphism (only products are audited — C5).
class CreateProductAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :product_audits do |t|
      t.bigint :product_id, null: false
      t.string :action, null: false
      t.jsonb :changes_data, null: false, default: {}
      t.string :actor, null: false
      t.datetime :created_at, null: false
    end

    add_index :product_audits, :product_id
  end
end
