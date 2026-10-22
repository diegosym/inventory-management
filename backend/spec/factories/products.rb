FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    description { "Demo product" }
    price { 19.99 }
    stock { 10 }
    # D-6: uppercase letters, digits and hyphens only.
    sequence(:sku) { |n| "SKU-#{n}" }
    active { true }
  end
end
