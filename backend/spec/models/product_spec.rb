require 'rails_helper'

# T2 — Product model: every rule and boundary of RF-1 (and RF-4's model leg),
# with SKU normalization per D-6 and validations living in the model (C9).
RSpec.describe Product, type: :model do
  describe 'factory defaults (D-6)' do
    it 'builds a valid product' do
      expect(build(:product)).to be_valid
    end
  end

  describe 'name (RF-1)' do
    it 'requires a name' do
      product = build(:product, name: nil)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
    end

    it 'rejects a blank name' do
      product = build(:product, name: '   ')
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
    end

    it 'rejects a 2-character name' do
      product = build(:product, name: 'ab')
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include('is too short (minimum is 3 characters)')
    end

    it 'accepts a name of exactly 3 characters' do
      expect(build(:product, name: 'abc')).to be_valid
    end

    it 'accepts a name of exactly 100 characters' do
      expect(build(:product, name: 'a' * 100)).to be_valid
    end

    it 'rejects a 101-character name' do
      product = build(:product, name: 'a' * 101)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include('is too long (maximum is 100 characters)')
    end
  end

  describe 'description (RF-1)' do
    it 'normalizes a nil description to an empty string' do
      product = build(:product, description: nil)
      expect(product).to be_valid
      expect(product.description).to eq('')
    end

    it 'accepts an empty description' do
      expect(build(:product, description: '')).to be_valid
    end

    it 'accepts exactly 1000 characters' do
      expect(build(:product, description: 'd' * 1000)).to be_valid
    end

    it 'rejects 1001 characters' do
      product = build(:product, description: 'd' * 1001)
      expect(product).not_to be_valid
      expect(product.errors[:description]).to include('is too long (maximum is 1000 characters)')
    end
  end

  describe 'price (RF-1)' do
    it 'requires a price' do
      product = build(:product, price: nil)
      expect(product).not_to be_valid
      expect(product.errors[:price]).to be_present
    end

    it 'rejects a non-numeric price' do
      product = build(:product, price: 'abc')
      expect(product).not_to be_valid
      expect(product.errors[:price]).to include('is not a number')
    end

    it 'rejects 0' do
      product = build(:product, price: 0)
      expect(product).not_to be_valid
      expect(product.errors[:price]).to include('must be greater than 0')
    end

    it 'rejects a negative price' do
      product = build(:product, price: -1.5)
      expect(product).not_to be_valid
      expect(product.errors[:price]).to include('must be greater than 0')
    end

    it 'rejects more than 2 decimal places (9.999) instead of letting the database round' do
      product = build(:product, price: 9.999)
      expect(product).not_to be_valid
      expect(product.errors[:price]).to be_present
    end

    it 'accepts a price with up to 2 decimals' do
      expect(build(:product, price: 49.99)).to be_valid
      expect(build(:product, price: '10.5')).to be_valid
      expect(build(:product, price: 100)).to be_valid
    end
  end

  describe 'stock (RF-1)' do
    it 'defaults to 0' do
      expect(Product.new.stock).to eq(0)
    end

    it 'accepts 0' do
      expect(build(:product, stock: 0)).to be_valid
    end

    it 'rejects a negative stock' do
      product = build(:product, stock: -1)
      expect(product).not_to be_valid
      expect(product.errors[:stock]).to include('must be greater than or equal to 0')
    end

    it 'rejects a non-numeric stock' do
      product = build(:product, stock: 'abc')
      expect(product).not_to be_valid
      expect(product.errors[:stock]).to include('is not a number')
    end

    it 'rejects a non-integer stock' do
      product = build(:product, stock: 1.5)
      expect(product).not_to be_valid
      expect(product.errors[:stock]).to be_present
    end
  end

  describe 'sku (D-6, RF-1)' do
    it 'requires a sku' do
      product = build(:product, sku: nil)
      expect(product).not_to be_valid
      expect(product.errors[:sku]).to include("can't be blank")
    end

    it 'rejects an empty sku' do
      product = build(:product, sku: '')
      expect(product).not_to be_valid
      expect(product.errors[:sku]).to include("can't be blank")
    end

    it 'normalizes lowercase input before validating: abc-123 -> ABC-123' do
      product = build(:product, sku: 'abc-123')
      expect(product).to be_valid
      expect(product.sku).to eq('BROKEN-FOR-RUN-ALL-DRILL')
    end

    it 'stores the normalized sku' do
      product = create(:product, sku: 'abc-123')
      expect(product.reload.sku).to eq('ABC-123')
    end

    it 'accepts the valid D-6 formats' do
      %w[ABC123 ABC-123 A-1].each do |sku|
        expect(build(:product, sku: sku)).to be_valid
      end
    end

    it 'rejects a sku with spaces' do
      product = build(:product, sku: 'ABC 123')
      expect(product).not_to be_valid
      expect(product.errors[:sku]).to include('is invalid')
    end

    it 'rejects characters outside [A-Z0-9-]' do
      product = build(:product, sku: 'abc@123')
      expect(product).not_to be_valid
      expect(product.errors[:sku]).to include('is invalid')
    end

    it 'rejects non-ASCII letters' do
      product = build(:product, sku: 'ÁBC123')
      expect(product).not_to be_valid
      expect(product.errors[:sku]).to include('is invalid')
    end

    it 'rejects a duplicate sku even when the case differs' do
      create(:product, sku: 'ABC-123')
      duplicate = build(:product, sku: 'abc-123')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sku]).to include('has already been taken')
    end

    it 'keeps its own sku valid on update' do
      product = create(:product)
      expect { product.update!(sku: product.sku) }.not_to raise_error
    end

    it 'is backed by a unique index in PostgreSQL' do
      create(:product, sku: 'DUP-1')
      duplicate = Product.new(name: 'Duplicate', sku: 'DUP-1', price: 1, stock: 0)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'active (RF-1, RF-4)' do
    it 'defaults to true' do
      expect(Product.new.active).to be(true)
    end

    it 'is valid without an explicit active value (default applies)' do
      product = Product.new(name: 'No Flag', sku: 'NF-1', price: 1, stock: 0)
      expect(product).to be_valid
      expect(product.active).to be(true)
    end

    it 'accepts true and false' do
      expect(build(:product, active: true)).to be_valid
      expect(build(:product, active: false)).to be_valid
    end

    it 'rejects nil (active: null)' do
      product = build(:product, active: nil)
      expect(product).not_to be_valid
      expect(product.errors[:active]).to be_present
    end

    it 'rejects non-boolean values instead of casting them to true' do
      product = build(:product, active: 'yes')
      expect(product).not_to be_valid
      expect(product.errors[:active]).to be_present
    end
  end
end
