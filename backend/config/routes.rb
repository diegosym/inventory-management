Rails.application.routes.draw do
  # RF-3: exactly the five /api/v1/products routes. `index`, `create` and
  # `update` actions land with T4 (create/update) and T5 (index).
  namespace :api do
    namespace :v1 do
      resources :products, only: %i[index show create update destroy]
    end
  end
end
