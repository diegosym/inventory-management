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

  # ---- Spec 004 T4 — audit guarantees (RF-6 atomicity leg, RF-7 rejected/no-op
  # legs, RF-8 internal-only surface). The audit insert happens in
  # `Product#write_audit` (T3, D-P37), so that is the point stubbed to raise.

  describe 'RF-6 atomicity: the entry is written in the change transaction' do
    it 'rolls back the create and leaves no entry when the audit insert raises' do
      allow_any_instance_of(Product).to receive(:write_audit)
        .and_raise(ActiveRecord::StatementInvalid, 'audit insert failed')

      products_before = Product.count

      expect {
        post '/api/v1/products',
             params: { product: { name: 'Atomic Product', price: 10, stock: 1,
                                  sku: 'ATOMIC-1' } },
             as: :json
      }.not_to change(ProductAudit, :count)

      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'internal_error',
                     'message' => 'Internal server error' }
      )
      expect(Product.count).to eq(products_before)
      expect(Product.unscoped.where(sku: 'ATOMIC-1')).to be_empty
    end

    it 'rolls back the update and leaves no entry when the audit insert raises' do
      product = create(:product, name: 'Stable Name', price: 10, stock: 1,
                                  sku: 'ATOMIC-2')
      snapshot = product.reload.attributes

      allow_any_instance_of(Product).to receive(:write_audit)
        .and_raise(ActiveRecord::StatementInvalid, 'audit insert failed')

      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: 'Renamed Product', description: product.description,
                                 price: product.price, stock: product.stock,
                                 sku: product.sku, active: product.active } },
            as: :json
      }.not_to change(ProductAudit, :count)

      expect(response).to have_http_status(:internal_server_error)
      expect(product.reload.attributes).to eq(snapshot)
      expect(entries_for(product).map(&:action)).to eq(['create'])
    end
  end

  describe 'RF-6/RF-7: a rejected request (422) persists nothing and audits nothing' do
    it 'an invalid create answers 422 with per-field details and records no entry' do
      products_before = Product.count
      entries_before = ProductAudit.count

      post '/api/v1/products',
           params: { product: { name: 'AB', price: -1, stock: -5, sku: 'abc 123' } },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq(
        'error' => {
          'code' => 'validation_failed',
          'message' => 'Validation failed',
          'details' => {
            'name' => ['is too short (minimum is 3 characters)'],
            'price' => ['must be greater than 0'],
            'stock' => ['must be greater than or equal to 0'],
            'sku' => ['is invalid']
          }
        }
      )
      expect(Product.count).to eq(products_before)
      expect(ProductAudit.count).to eq(entries_before)
    end

    it 'an invalid update answers 422 with per-field details, changing and auditing nothing' do
      product = create(:product, name: 'Valid Name', price: 10, stock: 1, sku: 'REJ-1')
      snapshot = product.reload.attributes
      entries_before = ProductAudit.count

      put "/api/v1/products/#{product.id}",
          params: { product: { name: 'AB', description: product.description,
                               price: 10, stock: 1, sku: 'REJ-1',
                               active: product.active } },
          as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('name' => ['is too short (minimum is 3 characters)'])
      expect(product.reload.attributes).to eq(snapshot)
      expect(ProductAudit.count).to eq(entries_before)
    end
  end

  describe 'RF-8: reads never audit' do
    it 'records no entry on GET — index, filtered search, and show' do
      product = create(:product, name: 'Read-only Product', sku: 'READ-1')

      expect {
        get '/api/v1/products'
        expect(response).to have_http_status(:ok)
        get '/api/v1/products', params: { q: 'read', active: 'true', page: 1 }
        expect(response).to have_http_status(:ok)
        get "/api/v1/products/#{product.id}"
        expect(response).to have_http_status(:ok)
      }.not_to change(ProductAudit, :count)
    end

    it 'a non-numeric id answers 404 (never 500) and records no entry' do
      product = create(:product, name: 'Untouched Product', sku: 'NUM-1')
      snapshot = product.reload.attributes
      entries_before = ProductAudit.count

      get '/api/v1/products/abc'
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )

      put '/api/v1/products/abc',
          params: { product: { name: 'Renamed By Nobody', price: 10, stock: 1,
                               sku: 'NUM-1' } },
          as: :json
      expect(response).to have_http_status(:not_found)

      delete '/api/v1/products/abc'
      expect(response).to have_http_status(:not_found)

      expect(product.reload.attributes).to eq(snapshot)
      expect(ProductAudit.count).to eq(entries_before)
    end
  end

  describe 'RF-8: the audit table is internal-only' do
    it 'no product response of any endpoint ever contains audit data' do
      product_keys = %w[id name description price stock sku active created_at updated_at]

      post '/api/v1/products',
           params: { product: { name: 'Surface Product', description: 'T4 run',
                                price: 15, stock: 2, sku: 'SURF-1', active: true } },
           as: :json
      expect(response).to have_http_status(:created)
      create_body = JSON.parse(response.body)
      product = Product.find(create_body['data']['id'])

      put "/api/v1/products/#{product.id}",
          params: { product: { name: 'Surface Renamed', description: 'T4 run',
                               price: 15, stock: 5, sku: 'SURF-1', active: true } },
          as: :json
      expect(response).to have_http_status(:ok)
      update_body = JSON.parse(response.body)

      get "/api/v1/products/#{product.id}"
      expect(response).to have_http_status(:ok)
      show_body = JSON.parse(response.body)

      get '/api/v1/products'
      expect(response).to have_http_status(:ok)
      index_body = JSON.parse(response.body)

      expect(create_body['data'].keys).to match_array(product_keys)
      expect(update_body['data'].keys).to match_array(product_keys)
      expect(show_body['data'].keys).to match_array(product_keys)
      expect(index_body.keys).to match_array(%w[data meta])
      expect(index_body['data'].map { |item| item.keys }).to all(match_array(product_keys))

      # The serialized values never smuggle the audit trail either.
      [create_body, update_body, show_body, index_body].each do |body|
        expect(body.to_json).not_to match(/audit/i)
      end
    end

    # The routes are the table's whole HTTP surface: with none defined, the
    # framework answers before any controller runs.
    it 'defines no route for the table, so a request to it is a 404' do
      route_paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }
      expect(route_paths.grep(/product_audit/)).to be_empty

      get '/api/v1/product_audits'
      expect(response).to have_http_status(:not_found)
    end
  end
end
