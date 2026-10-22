require 'rails_helper'

# T5: listing endpoint (RF-9…RF-14, RF-16). Pagination (fixed 10/page), name
# search (`q`, case-insensitive substring), and `active` filter are always
# resolved in PostgreSQL (C11), combined with the stable order
# `created_at DESC, id DESC` (RF-12). Malformed query params answer 422 with
# parameter-keyed details (RF-13, D-P11); out-of-range pages answer 200 with
# an empty list and the requested page echoed (RF-13); no match answers 200
# empty, never 404 (RF-14). Response shape: `{ "data": [ … ],
# "meta": { current_page, total_count, total_pages } }` (plan, D-7).
RSpec.describe 'Api::V1::Products listing' do
  describe 'GET /api/v1/products (pagination, RF-9)' do
    it 'returns the first 10 products with the pagination metadata' do
      create_list(:product, 23)

      get '/api/v1/products'

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].size).to eq(10)
      expect(body['data'].map { |p| p['id'] })
        .to eq(Product.order(:id).pluck(:id).last(10).reverse)
      expect(body['meta'])
        .to eq('current_page' => 1, 'total_count' => 23, 'total_pages' => 3)
    end

    it 'returns page 2 and page 3 with the remaining products' do
      create_list(:product, 23)
      ids_desc = Product.order(:id).pluck(:id).reverse

      get '/api/v1/products', params: { page: 2 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].map { |p| p['id'] }).to eq(ids_desc[10, 10])
      expect(body['meta'])
        .to eq('current_page' => 2, 'total_count' => 23, 'total_pages' => 3)

      get '/api/v1/products', params: { page: 3 }

      body = JSON.parse(response.body)
      expect(body['data'].map { |p| p['id'] }).to eq(ids_desc[20, 3])
      expect(body['meta'])
        .to eq('current_page' => 3, 'total_count' => 23, 'total_pages' => 3)
    end

    # RF-12: pages are stable — identical created_at values fall back to
    # id DESC, and no product is lost or repeated between consecutive pages.
    it 'orders by created_at DESC with id DESC as the stable tie-breaker' do
      stamp = Time.zone.parse('2026-01-01T10:00:00Z')
      older = create(:product, name: 'Older Product', created_at: stamp - 1.hour)
      tied = create_list(:product, 11, created_at: stamp)
      ids_desc = tied.map(&:id).reverse

      get '/api/v1/products', params: { page: 1 }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] })
        .to eq(ids_desc.first(10))

      get '/api/v1/products', params: { page: 2 }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] })
        .to eq(ids_desc.drop(10) + [older.id])
    end
  end

  describe 'GET /api/v1/products (search, RF-10)' do
    it 'returns only names containing the term, case-insensitively' do
      keyboard = create(:product, name: 'Mechanical Keyboard')
      create(:product, name: 'mechanical mouse')
      create(:product, name: 'Ergonomic Stand')

      get '/api/v1/products', params: { q: 'KEYBOARD' }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].map { |p| p['id'] }).to eq([keyboard.id])
      expect(body['meta'])
        .to eq('current_page' => 1, 'total_count' => 1, 'total_pages' => 1)
    end

    # Plan behavioral note: `%` and `_` in the term match literally.
    it 'escapes % and _ so they match literally' do
      promotion = create(:product, name: 'Sale 50% Off')
      variant = create(:product, name: 'A_B Variant')
      create(:product, name: 'Plain Product')

      get '/api/v1/products', params: { q: '50%' }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] })
        .to eq([promotion.id])

      get '/api/v1/products', params: { q: '_' }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] })
        .to eq([variant.id])
    end

    # RF-10: whitespace-only (or empty) `q` counts as no term -> full listing.
    it 'treats a whitespace-only or empty term as no term' do
      create_list(:product, 3)

      get '/api/v1/products', params: { q: '   ' }
      expect(JSON.parse(response.body)['data'].size).to eq(3)

      get '/api/v1/products', params: { q: '' }
      expect(JSON.parse(response.body)['data'].size).to eq(3)
      expect(JSON.parse(response.body)['meta']['total_count']).to eq(3)
    end

    # RF-14: no match answers 200 with an empty list, never 404.
    it 'answers 200 with an empty list when nothing matches' do
      create_list(:product, 2)

      get '/api/v1/products', params: { q: 'zzz-no-match' }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body))
        .to eq('data' => [],
               'meta' => { 'current_page' => 1, 'total_count' => 0,
                           'total_pages' => 0 })
    end
  end

  describe 'GET /api/v1/products (active filter, RF-11)' do
    it 'returns only active or only inactive products as requested' do
      actives = create_list(:product, 2, active: true)
      inactives = create_list(:product, 3, active: false)

      get '/api/v1/products', params: { active: 'true' }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] })
        .to match_array(actives.map(&:id))
      expect(JSON.parse(response.body)['meta']['total_count']).to eq(2)

      get '/api/v1/products', params: { active: 'false' }
      expect(JSON.parse(response.body)['data'].map { |p| p['id'] })
        .to match_array(inactives.map(&:id))
      expect(JSON.parse(response.body)['meta']['total_count']).to eq(3)
    end

    it 'answers 200 with an empty list when the filter matches nothing' do
      create_list(:product, 2, active: true)

      get '/api/v1/products', params: { active: 'false' }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to eq([])
      expect(JSON.parse(response.body)['meta'])
        .to eq('current_page' => 1, 'total_count' => 0, 'total_pages' => 0)
    end
  end

  describe 'GET /api/v1/products (search + filter + pagination combined, RF-12)' do
    it 'applies q, active, and page together, server-side' do
      gadgets = create_list(:product, 14, name: 'Gadget Small', active: true)
      create_list(:product, 3, name: 'Gadget Inactive', active: false)
      create_list(:product, 5, name: 'Other Thing', active: true)

      get '/api/v1/products', params: { q: 'gadget', active: 'true', page: 2 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].size).to eq(4)
      expect(body['data'].map { |p| p['id'] })
        .to eq(gadgets.map(&:id).reverse.drop(10))
      expect(body['data'].map { |p| p['name'] }.uniq).to eq(['Gadget Small'])
      expect(body['meta'])
        .to eq('current_page' => 2, 'total_count' => 14, 'total_pages' => 2)
    end
  end

  describe 'GET /api/v1/products (malformed params, RF-13)' do
    it 'answers 422 with the standard shape and parameter-keyed details' do
      get '/api/v1/products', params: { page: 'abc' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq(
        'error' => {
          'code' => 'validation_failed',
          'message' => 'Validation failed',
          'details' => { 'page' => ['must be a positive integer'] }
        }
      )
    end

    it 'answers 422 for an empty page' do
      get '/api/v1/products', params: { page: '' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('page' => ['must be a positive integer'])
    end

    it 'answers 422 for a non-positive page' do
      get '/api/v1/products', params: { page: 0 }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('page' => ['must be a positive integer'])
    end

    it 'answers 422 for active values other than true/false' do
      get '/api/v1/products', params: { active: 'maybe' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('active' => ['must be true or false'])
    end

    it 'answers 422 for an empty active' do
      get '/api/v1/products', params: { active: '' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('active' => ['must be true or false'])
    end

    it 'answers 422 for a non-string q' do
      get '/api/v1/products', params: { q: %w[ab cd] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('q' => ['must be a string'])
    end

    it 'reports every malformed parameter together in details' do
      get '/api/v1/products', params: { page: 'abc', active: 'maybe' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']['details'])
        .to eq('page' => ['must be a positive integer'],
               'active' => ['must be true or false'])
    end

    # RF-13: a valid but out-of-range page answers 200 with an empty list and
    # `current_page` echoing the requested page.
    it 'answers 200 with an empty list echoing an out-of-range page' do
      create_list(:product, 3)

      get '/api/v1/products', params: { page: 5 }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body))
        .to eq('data' => [],
               'meta' => { 'current_page' => 5, 'total_count' => 3,
                           'total_pages' => 1 })
    end
  end
end
