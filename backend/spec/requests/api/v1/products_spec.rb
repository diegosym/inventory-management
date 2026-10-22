require 'rails_helper'

# T3: read/delete endpoints and the 404 leg of the error contract (RF-3,
# RF-5, RF-6). Success bodies wrap the product in `data` with `price` as a
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

  describe 'DELETE /api/v1/products/:id' do
    it 'removes the product and answers 204 with an empty body' do
      product = create(:product)

      expect { delete "/api/v1/products/#{product.id}" }
        .to change(Product, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
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
