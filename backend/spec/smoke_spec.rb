require 'rails_helper'

# Suite smoke test (T1): the app boots and talks to the compose database.
RSpec.describe 'Suite smoke' do
  it 'boots the Rails environment' do
    expect(Rails.application).to be_present
  end

  it 'connects to the test database' do
    expect(ActiveRecord::Base.connection.execute('SELECT 1').values).to eq([[1]])
  end
end
