require 'rails_helper'

# RF-15: the seeds produce a functional demo dataset and are idempotent.
RSpec.describe 'Demo seeds' do
  before do
    Product.delete_all
    Rails.application.load_seed
  end

  it 'creates more than 10 products (at least two pages)' do
    expect(Product.count).to be > 10
  end

  it 'includes a mix of active and inactive products' do
    expect(Product.where(active: true)).to be_present
    expect(Product.where(active: false)).to be_present
  end

  it 'only uses D-6-valid SKUs (uppercase letters, digits, hyphens)' do
    expect(Product.pluck(:sku)).to all(match(/\A[A-Z0-9-]+\z/))
  end

  it 'keeps every price greater than 0' do
    expect(Product.minimum(:price)).to be > 0
  end

  it 'is idempotent: a second run does not duplicate the dataset' do
    count_before = Product.count
    skus_before = Product.pluck(:sku)

    Rails.application.load_seed

    expect(Product.count).to eq(count_before)
    expect(Product.pluck(:sku)).to match_array(skus_before)
  end

  # Spec 004 T5 (D-16a): `find_or_create_by!` runs default-scoped, so a
  # soft-deleted demo product is *not* found — creation goes through (the SKU
  # uniqueness and the partial index only cover visible rows) and the demo
  # product is resurrected under a new id while the old row stays deleted.
  it 'resurrects a soft-deleted product under a new id (D-16a)' do
    original = Product.find_by!(sku: 'KB-001')
    visible_before = Product.count

    original.soft_delete!
    expect(Product.exists?(sku: 'KB-001')).to be(false)

    Rails.application.load_seed

    resurrected = Product.find_by!(sku: 'KB-001')
    expect(resurrected).to be_present
    expect(resurrected.id).not_to eq(original.id)

    old_row = Product.unscoped.find_by(id: original.id)
    expect(old_row).to be_present
    expect(old_row.deleted_at).to be_present

    # No visible product was duplicated by the resurrection.
    expect(Product.where(sku: 'KB-001').count).to eq(1)
    expect(Product.count).to eq(visible_before)
  end

  # Spec 004 T5 (D-15): seeded creations go through the same model callbacks
  # as the API, so every seeded product carries an audit entry, action
  # `create`, with the constant actor `"system"`.
  it 'audits every seeded product with a create entry by actor "system" (D-15)' do
    Product.find_each do |product|
      entry = product.product_audits.find_by!(action: 'create')
      expect(entry.actor).to eq('system')
    end
  end
end
