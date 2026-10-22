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
end
