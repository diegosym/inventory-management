require 'rails_helper'

# Spec 004 T3 (RF-6, RF-7): every successful product change records exactly one
# audit entry in the internal `product_audits` table, with actor `"system"`
# (D-15). Content per D-P38: create = every created business value of the
# persisted row with `from: null` (not `saved_changes`, which omits attributes
# equal to their column default); update = only the business fields that
# actually changed on persisted values (D-16c), before/after; delete = no field
# values at all (`changes_data == {}`, D-16b). Values are serialized like the
# API (price as a 2-decimal string). The table has no endpoint (RF-8, asserted
# in T4).
RSpec.describe 'Api::V1::Products audit entries' do
  def entries_for(product)
    ProductAudit.where(product_id: product.id).order(:created_at)
  end

  describe 'RF-6/RF-7: create records exactly one entry with the created values' do
    it 'records one create entry: action, actor "system", timestamp, every business value with from null' do
      expect {
        post '/api/v1/products',
             params: { product: { name: 'Audited Product', description: 'First run',
                                  price: 49.9, stock: 7, sku: 'AUD-1', active: false } },
             as: :json
      }.to change(ProductAudit, :count).by(1)

      expect(response).to have_http_status(:created)
      product = Product.find(JSON.parse(response.body)['data']['id'])
      entry = entries_for(product).sole
      expect(entry.action).to eq('create')
      expect(entry.actor).to eq('system')
      expect(entry.created_at).to be_present
      expect(entry.changes_data).to eq(
        'name' => { 'from' => nil, 'to' => 'Audited Product' },
        'description' => { 'from' => nil, 'to' => 'First run' },
        'price' => { 'from' => nil, 'to' => '49.90' },
        'stock' => { 'from' => nil, 'to' => 7 },
        'sku' => { 'from' => nil, 'to' => 'AUD-1' },
        'active' => { 'from' => nil, 'to' => false }
      )
    end

    # The create entry comes from the persisted row, not `saved_changes`:
    # omitted attributes equal to their column default are still recorded.
    it 'records defaulted business values too when the payload omits them' do
      post '/api/v1/products',
           params: { product: { name: 'Minimal Product', price: 10, sku: 'AUD-2' } },
           as: :json

      expect(response).to have_http_status(:created)
      product = Product.find(JSON.parse(response.body)['data']['id'])
      entry = entries_for(product).sole
      expect(entry.changes_data).to eq(
        'name' => { 'from' => nil, 'to' => 'Minimal Product' },
        'description' => { 'from' => nil, 'to' => '' },
        'price' => { 'from' => nil, 'to' => '10.00' },
        'stock' => { 'from' => nil, 'to' => 0 },
        'sku' => { 'from' => nil, 'to' => 'AUD-2' },
        'active' => { 'from' => nil, 'to' => true }
      )
    end
  end

  describe 'RF-6/RF-7: update records exactly one entry per changed field' do
    it 'covers every changed field with before/after and leaves unchanged fields out' do
      product = create(:product, name: 'Old Name', description: 'Same description',
                                 price: 10.0, stock: 1, sku: 'UPD-1', active: true)

      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: 'New Name', price: 20.5, stock: 3,
                                 description: 'Same description', sku: 'UPD-1',
                                 active: true } },
            as: :json
      }.to change(ProductAudit, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(entries_for(product).map(&:action)).to eq(%w[create update])
      entry = entries_for(product).last
      expect(entry.actor).to eq('system')
      expect(entry.changes_data).to eq(
        'name' => { 'from' => 'Old Name', 'to' => 'New Name' },
        'price' => { 'from' => '10.00', 'to' => '20.50' },
        'stock' => { 'from' => 1, 'to' => 3 }
      )
    end
  end

  describe 'RF-7: "changed" is judged on persisted values (D-16c)' do
    # `price: "49.9"` over the stored 49.90 and `description: null` over the
    # stored "" type-cast to the same values: nothing changed, no entry.
    it 'records no entry for an equivalent payload' do
      product = create(:product, description: '', price: 49.9, sku: 'EQ-1')

      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: product.name, description: nil,
                                 price: '49.9', stock: product.stock,
                                 sku: 'EQ-1', active: true } },
            as: :json
      }.not_to change(ProductAudit, :count)

      expect(response).to have_http_status(:ok)
    end

    it 'records no entry for an identical payload' do
      product = create(:product, sku: 'NOOP-1')

      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: product.name, description: product.description,
                                 price: product.price, stock: product.stock,
                                 sku: product.sku, active: product.active } },
            as: :json
      }.not_to change(ProductAudit, :count)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'RF-6/RF-7: soft delete records exactly one entry without a snapshot' do
    it 'records one delete entry with empty changes_data and no extra update entry' do
      product = create(:product, sku: 'DEL-1')

      expect { delete "/api/v1/products/#{product.id}" }
        .to change(ProductAudit, :count).by(1)

      expect(response).to have_http_status(:no_content)
      expect(entries_for(product).map(&:action)).to eq(%w[create delete])
      entry = entries_for(product).last
      expect(entry.action).to eq('delete')
      expect(entry.actor).to eq('system')
      expect(entry.created_at).to be_present
      expect(entry.changes_data).to eq({})
    end

    it 'a repeated DELETE answers 404 and records no second entry' do
      product = create(:product, sku: 'DEL-2')
      delete "/api/v1/products/#{product.id}"

      expect { delete "/api/v1/products/#{product.id}" }
        .not_to change(ProductAudit, :count)

      expect(response).to have_http_status(:not_found)
      expect(entries_for(product).map(&:action)).to eq(%w[create delete])
    end
  end
end
