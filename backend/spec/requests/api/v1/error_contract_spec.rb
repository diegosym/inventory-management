require 'rails_helper'

# T3: the 500 leg of the single error contract (RF-7, C10) — a simulated
# unexpected exception answers 500 with only the generic code + message and
# never leaks internals. The CORS examples land here with spec 001 / T6.
RSpec.describe 'Error contract' do
  describe 'unexpected exception (500)' do
    it 'renders the generic internal_error shape and leaks no internals' do
      allow(Product).to receive(:find_by!).and_raise('secret database detail')

      get '/api/v1/products/1'

      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)).to eq(
        'error' => {
          'code' => 'internal_error',
          'message' => 'Internal server error'
        }
      )
      expect(response.body).not_to include('secret database detail')
    end
  end

  # T6: CORS for the frontend origin (RF-8) — the allowed origin from
  # FRONTEND_ORIGIN gets Allow-Origin on a simple request and on the preflight
  # OPTIONS; any other origin gets no CORS headers at all.
  describe 'CORS' do
    let(:frontend_origin) { ENV.fetch('FRONTEND_ORIGIN', 'http://localhost:5173') }

    it 'answers a preflight OPTIONS with the allowed methods and headers' do
      options '/api/v1/products', headers: {
        'Origin' => frontend_origin,
        'Access-Control-Request-Method' => 'PUT',
        'Access-Control-Request-Headers' => 'Content-Type'
      }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Access-Control-Allow-Origin']).to eq(frontend_origin)
      expect(response.headers['Access-Control-Allow-Methods']).to include('PUT', 'DELETE', 'OPTIONS')
      expect(response.headers['Access-Control-Allow-Headers']).to include('Content-Type')
    end

    it 'includes Allow-Origin on a normal cross-origin request' do
      get '/api/v1/products', headers: { 'Origin' => frontend_origin }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Access-Control-Allow-Origin']).to eq(frontend_origin)
    end

    it 'omits CORS headers for a disallowed origin' do
      get '/api/v1/products', headers: { 'Origin' => 'http://evil.example' }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Access-Control-Allow-Origin']).to be_nil
    end
  end
end
