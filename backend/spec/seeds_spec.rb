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
end
