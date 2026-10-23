require 'rails_helper'

# T3: read/delete endpoints and the 404 leg of the error contract (RF-3,
# RF-5, RF-6). T4: create/update with the `{ "product": { … } }` wrapper, the
# 422 leg with per-field details (RF-2), and PUT full-replacement semantics
# (RF-4). Success bodies wrap the product in `data` with `price` as a
# 2-decimal string (plan D-P5, D-7).
RSpec.describe 'Api::V1::Products' do
  describe 'GET /api/v1/products/:id' do
    it 'returns the product wrapped in data, price as a 2-decimal string' do
      product = create(:product, price: 49.99)

      get "/api/v1/products/#{product.id}"

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      expect(data).to eq(
        'id' => product.id,
        'name' => product.name,
        'description' => product.description,
        'price' => '49.99',
        'stock' => product.stock,
        'sku' => product.sku,
        'active' => true,
        'created_at' => product.created_at.utc.iso8601,
        'updated_at' => product.updated_at.utc.iso8601
      )
    end

    it 'returns 404 with the standard shape for an unknown id' do
      get '/api/v1/products/99999999'

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )
    end

    it 'returns 404 (never 500) for a non-numeric id' do
      get '/api/v1/products/abc'

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )
    end
  end

  describe 'POST /api/v1/products' do
    it 'creates the product, answers 201 with data, and stores the SKU normalized (D-6)' do
      expect {
        post '/api/v1/products',
             params: { product: { name: 'Mechanical Keyboard', description: 'Brown switches',
                                  price: 49.99, stock: 12, sku: 'abc-123' } },
             as: :json
      }.to change(Product, :count).by(1)

      expect(response).to have_http_status(:created)
      product = Product.order(:id).last
      expect(JSON.parse(response.body)['data']).to eq(
        'id' => product.id,
        'name' => 'Mechanical Keyboard',
        'description' => 'Brown switches',
        'price' => '49.99',
        'stock' => 12,
        'sku' => 'ABC-123',
        'active' => true,
        'created_at' => product.created_at.utc.iso8601,
        'updated_at' => product.updated_at.utc.iso8601
      )
      expect(product.sku).to eq('ABC-123')
    end

    it 'answers 422 with per-field details and persists nothing' do
      expect {
        post '/api/v1/products',
             params: { product: { name: 'AB', price: -1, stock: -5, sku: 'abc 123' } },
             as: :json
      }.not_to change(Product, :count)

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
    end

    it 'answers 422 when the SKU is already taken' do
      create(:product, sku: 'TAKEN-1')

      expect {
        post '/api/v1/products',
             params: { product: { name: 'Duplicate SKU Product', price: 10, stock: 1,
                                  sku: 'taken-1' } },
             as: :json
      }.not_to change(Product, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('sku' => ['has already been taken'])
    end

    it 'answers 422 for a price with more than 2 decimals' do
      expect {
        post '/api/v1/products',
             params: { product: { name: 'Rounding Product', price: 9.999, stock: 1,
                                  sku: 'ROUND-1' } },
             as: :json
      }.not_to change(Product, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('price' => ['must have at most 2 decimal places'])
    end

    # A missing/null/empty wrapper behaves like an empty product: the model's
    # rules answer 422 (a client error must not surface as 500).
    it 'answers 422 (never 500) when the product wrapper is missing' do
      expect { post '/api/v1/products', as: :json }
        .not_to change(Product, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      # `stock`/`active`/`description` have column defaults, so only the
      # genuinely missing required fields are reported.
      details = JSON.parse(response.body)['error']['details']
      expect(details.keys).to match_array(%w[name price sku])
    end
  end

  describe 'PUT /api/v1/products/:id (full replacement, RF-4)' do
    it 'replaces every field and answers 200 with the updated product in data' do
      product = create(:product, name: 'Old Name', description: 'Old desc',
                                 price: 5.0, stock: 1, sku: 'OLD-1', active: true)

      put "/api/v1/products/#{product.id}",
          params: { product: { name: 'New Name', description: 'New desc', price: 75.5,
                               stock: 20, sku: 'new-1', active: false } },
          as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to include(
        'name' => 'New Name',
        'description' => 'New desc',
        'price' => '75.50',
        'stock' => 20,
        'sku' => 'NEW-1',
        'active' => false
      )
      product.reload
      expect(product.price).to eq(BigDecimal('75.5'))
      expect(product.attributes.slice('name', 'description', 'stock', 'sku', 'active'))
        .to eq('name' => 'New Name', 'description' => 'New desc', 'stock' => 20,
               'sku' => 'NEW-1', 'active' => false)
    end

    # Edge case (a): omitting `active` on an inactive product keeps it inactive
    # (never resets to true).
    it 'keeps the current active value when active is omitted' do
      product = create(:product, active: false)

      put "/api/v1/products/#{product.id}",
          params: { product: { name: 'Still Inactive Product', sku: product.sku,
                               price: 10, stock: 1 } },
          as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['active']).to be(false)
      expect(product.reload.active).to be(false)
    end

    # Edge case (b): omitted description -> stored empty.
    it 'stores an empty description when description is omitted' do
      product = create(:product, description: 'Something long')

      put "/api/v1/products/#{product.id}",
          params: { product: { name: 'No Description Product', sku: product.sku,
                               price: 10, stock: 1 } },
          as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['description']).to eq('')
      expect(product.reload.description).to eq('')
    end

    # Edge case (b): null description -> stored empty.
    it 'stores an empty description when description is null' do
      product = create(:product, description: 'Something long')

      put "/api/v1/products/#{product.id}",
          params: { product: { name: 'Null Description Product', description: nil,
                               sku: product.sku, price: 10, stock: 1 } },
          as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['description']).to eq('')
      expect(product.reload.description).to eq('')
    end

    # Edge case (c): `active: null` -> 422 and nothing persisted.
    it 'answers 422 when active is null' do
      product = create(:product, name: 'Untouched Product', active: true)

      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: 'Renamed Attempt', sku: product.sku, price: 10,
                                 stock: 1, active: nil } },
            as: :json
      }.not_to change { product.reload.attributes }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('active' => ['is not included in the list'])
    end

    # Required field omitted (also pins "keeping the own SKU" as valid).
    it 'answers 422 when a required field is omitted, persisting nothing' do
      product = create(:product, name: 'Unchanged Name', stock: 10)

      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: 'Renamed Now', sku: product.sku, price: 10 } },
            as: :json
      }.not_to change { product.reload.attributes }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('stock' => ['is not a number'])
    end

    # Required field null.
    it 'answers 422 when a required field is null' do
      product = create(:product, price: 20.0)

      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: 'Valid New Name', sku: product.sku, price: nil,
                                 stock: 1 } },
            as: :json
      }.not_to change { product.reload.attributes }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('price' => ['is not a number'])
    end

    it "answers 422 when taking another product's SKU" do
      create(:product, sku: 'OTHER-1')
      product = create(:product, sku: 'MINE-1')

      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: 'Stolen SKU Product', sku: 'other-1', price: 10,
                                 stock: 1 } },
            as: :json
      }.not_to change { product.reload.attributes }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('sku' => ['has already been taken'])
    end

    it 'returns 404 with the standard shape for an unknown id' do
      put '/api/v1/products/99999999',
          params: { product: { name: 'Any Name', sku: 'ANY-1', price: 1, stock: 1 } },
          as: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )
    end

    it 'returns 404 (never 500) for a non-numeric id' do
      put '/api/v1/products/abc',
          params: { product: { name: 'Any Name', sku: 'ANY-1', price: 1, stock: 1 } },
          as: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']['code']).to eq('not_found')
    end
  end

  describe 'DELETE /api/v1/products/:id' do
    # Spec 004 RF-1 (the single D-16(d) adaptation): the delete is a soft
    # delete — the visible count drops, but the row remains with `deleted_at`
    # set (`Product.unscoped`).
    it 'soft-deletes the product, keeping the row, and answers 204 with an empty body' do
      product = create(:product)

      expect { delete "/api/v1/products/#{product.id}" }
        .to change(Product, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(Product.unscoped.find(product.id).deleted_at).to be_present
    end

    it 'returns 404 with the standard shape for an unknown id and deletes nothing' do
      expect { delete '/api/v1/products/99999999' }
        .not_to change(Product, :count)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )
    end

    it 'returns 404 (never 500) for a non-numeric id' do
      expect { delete '/api/v1/products/abc' }
        .not_to change(Product, :count)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']['code']).to eq('not_found')
    end
  end
end
