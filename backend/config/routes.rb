Rails.application.routes.draw do
  # RF-3: exactly the five /api/v1/products routes. All five actions exist
  # since T5 (index = server-side listing per RF-9…RF-14).
  namespace :api do
    namespace :v1 do
      resources :products, only: %i[index show create update destroy]
    end
  end
end
