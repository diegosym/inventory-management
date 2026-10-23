require 'rails_helper'

# Spec 004 T2 (RF-1…RF-5): DELETE marks the row as deleted instead of
# destroying it (`Product#soft_delete!`, plan D-P35) and the default scope
# makes every endpoint ignore deleted rows by construction. Success shapes
# (201/200/204) and the error contract (404 standard shape, C10) stay
# byte-identical to spec 001 (RF-5); SKU uniqueness holds only among visible
# rows (RF-4).
RSpec.describe 'Api::V1::Products soft delete' do
  describe 'RF-1: DELETE marks the product as deleted, keeping the row' do
    it 'answers 204 with an empty body and leaves the row with all its data' do
      product = create(:product, name: 'Keeper Product', sku: 'KEEP-1', active: false)

      expect { delete "/api/v1/products/#{product.id}" }
        .to change(Product, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty

      deleted = Product.unscoped.find(product.id)
      expect(deleted.deleted_at).to be_present
      expect(deleted.attributes.slice('name', 'description', 'price', 'stock',
                                      'sku', 'active'))
        .to eq(product.attributes.slice('name', 'description', 'price', 'stock',
                                        'sku', 'active'))
    end
  end

  describe 'RF-2: deleted products are invisible on GET /api/v1/products' do
    it 'excludes the deleted product from the listing, counting only visible rows' do
      visible = create_list(:product, 3)
      doomed = create(:product, name: 'Doomed Product')
      delete "/api/v1/products/#{doomed.id}"

      get '/api/v1/products'

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].map { |p| p['id'] }).to match_array(visible.map(&:id))
      expect(body['meta'])
        .to eq('current_page' => 1, 'total_count' => 3, 'total_pages' => 1)
    end

    it 'keeps the deleted product out of a `q` search' do
      visible = create(:product, name: 'Ghost Keyboard')
      doomed = create(:product, name: 'Ghost Mouse')
      delete "/api/v1/products/#{doomed.id}"

      get '/api/v1/products', params: { q: 'ghost' }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].map { |p| p['id'] }).to eq([visible.id])
      expect(body['meta']['total_count']).to eq(1)
    end

    it 'keeps the deleted product out of the `active` filter' do
      visible = create(:product, active: true)
      doomed = create(:product, active: true)
      delete "/api/v1/products/#{doomed.id}"

      get '/api/v1/products', params: { active: 'true' }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] })
        .to eq([visible.id])

      get '/api/v1/products', params: { active: 'false' }
      expect(JSON.parse(response.body)['data']).to eq([])
    end

    # Edge case: a deleted `active: false` product stays invisible under both
    # values of the filter.
    it 'keeps a deleted inactive product invisible under both filter values' do
      doomed = create(:product, active: false)
      visible = create(:product, active: false)
      delete "/api/v1/products/#{doomed.id}"

      get '/api/v1/products', params: { active: 'false' }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] })
        .to eq([visible.id])

      get '/api/v1/products', params: { active: 'true' }
      expect(JSON.parse(response.body)['data']).to eq([])
    end

    it 'computes total_count and total_pages over visible rows only' do
      products = create_list(:product, 12)
      delete "/api/v1/products/#{products.last.id}"
      delete "/api/v1/products/#{products[-2].id}"

      get '/api/v1/products'

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].map { |p| p['id'] })
        .to eq(products.first(10).map(&:id).reverse)
      expect(body['meta'])
        .to eq('current_page' => 1, 'total_count' => 10, 'total_pages' => 1)
    end

    # Edge case: a page beyond the last page after deletions still answers
    # 200 with an empty list and the requested page echoed (spec 001 RF-13).
    it 'answers 200 with an empty list echoing a page beyond the last after deletions' do
      products = create_list(:product, 11)
      delete "/api/v1/products/#{products.last.id}"
      delete "/api/v1/products/#{products[-2].id}"

      get '/api/v1/products', params: { page: 2 }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body))
        .to eq('data' => [],
               'meta' => { 'current_page' => 2, 'total_count' => 9,
                           'total_pages' => 1 })
    end
  end

  describe 'RF-3: a deleted id answers 404 with the standard error shape (C10)' do
    let!(:product) { create(:product, sku: 'GONE-3') }

    before do
      delete "/api/v1/products/#{product.id}"
      expect(response).to have_http_status(:no_content)
    end

    it 'show of the deleted id answers 404' do
      get "/api/v1/products/#{product.id}"

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )
    end

    it 'update of the deleted id answers 404 and changes nothing' do
      expect {
        put "/api/v1/products/#{product.id}",
            params: { product: { name: 'Renamed Ghost', sku: 'GONE-3', price: 10,
                                 stock: 1 } },
            as: :json
      }.not_to change { Product.unscoped.find(product.id).attributes }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )
    end

    # T3 adds the "no second audit entry" leg of a repeated DELETE (RF-3).
    it 'a repeated DELETE answers 404, keeps the row, and records no second entry' do
      audit_count = ProductAudit.count

      expect { delete "/api/v1/products/#{product.id}" }
        .not_to change { Product.unscoped.count }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )
      expect(Product.unscoped.find(product.id).deleted_at).to be_present
      expect(ProductAudit.count).to eq(audit_count)
    end

    it 'a non-numeric id answers 404 (never 500)' do
      get '/api/v1/products/abc'

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        'error' => { 'code' => 'not_found', 'message' => 'Product not found' }
      )
    end
  end

  describe 'RF-4: SKU uniqueness holds among non-deleted products only' do
    it 'creates a new product when reusing a deleted product SKU, keeping the old row' do
      original = create(:product, name: 'Original Product', sku: 'REUSE-1')
      delete "/api/v1/products/#{original.id}"

      expect {
        post '/api/v1/products',
             params: { product: { name: 'Reused SKU Product', price: 10, stock: 1,
                                  sku: 'reuse-1' } },
             as: :json
      }.to change(Product, :count).by(1)

      expect(response).to have_http_status(:created)
      new_id = JSON.parse(response.body)['data']['id']
      expect(new_id).not_to eq(original.id)

      old_row = Product.unscoped.find(original.id)
      expect(old_row.deleted_at).to be_present
      expect(old_row.sku).to eq('REUSE-1')
      expect(old_row.name).to eq('Original Product')
    end

    it 'still answers 422 with the per-field message when the SKU belongs to a visible product' do
      create(:product, sku: 'TAKEN-4')

      expect {
        post '/api/v1/products',
             params: { product: { name: 'Duplicate SKU Product', price: 10, stock: 1,
                                  sku: 'taken-4' } },
             as: :json
      }.not_to change(Product, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('sku' => ['has already been taken'])
    end
  end

  describe 'RF-5: spec-001 success shapes stay unchanged' do
    # Cheap re-assert of the five routes' success shapes (204/200/201) with
    # deleted rows present — no new field, no new wrapper (C10, RF-5).
    it 'keeps 204/200/201 shapes on every endpoint with deleted rows present' do
      visible = create(:product, name: 'Visible Product', sku: 'LIVE-5')
      doomed = create(:product, name: 'Doomed Product', sku: 'GONE-5')

      delete "/api/v1/products/#{doomed.id}"
      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty

      get '/api/v1/products'
      expect(response).to have_http_status(:ok)
      list = JSON.parse(response.body)
      expect(list.keys).to match_array(%w[data meta])
      expect(list['meta'].keys)
        .to match_array(%w[current_page total_count total_pages])

      get "/api/v1/products/#{visible.id}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data'].keys)
        .to match_array(%w[id name description price stock sku active created_at updated_at])

      put "/api/v1/products/#{visible.id}",
          params: { product: { name: 'Visible Product', price: 19.99, stock: 10,
                               sku: 'LIVE-5' } },
          as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data'].keys)
        .to match_array(%w[id name description price stock sku active created_at updated_at])

      post '/api/v1/products',
           params: { product: { name: 'Fresh Product', price: 5, stock: 1,
                                sku: 'FRESH-5' } },
           as: :json
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data'].keys)
        .to match_array(%w[id name description price stock sku active created_at updated_at])
    end
  end
end
