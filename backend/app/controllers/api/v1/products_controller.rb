module Api
  module V1
    class ProductsController < ApplicationController
      # RF-5: unknown AND non-numeric :id answer 404, never 500 — find_by!
      # casts through the integer primary-key type ("abc" -> 0), so the raw
      # string never reaches the PostgreSQL driver. T4 reuses it for update.
      before_action :find_product!, only: %i[show update destroy]

      # GET /api/v1/products/:id -> 200 { "data": { product } } (plan D-P5/D-7)
      def show
        render json: { data: serialize_product(@product) }
      end

      # POST /api/v1/products -> 201 { "data": { product } }; any invalid data
      # answers 422 with per-field details straight from the model (RF-2, C9).
      def create
        product = Product.new(product_params)
        product.save!
        render json: { data: serialize_product(product) }, status: :created
      end

      # PUT /api/v1/products/:id -> 200, full replacement (RF-4): every omitted
      # required field (and `description`) is assigned nil so the model decides
      # (422 for the required ones, "" for description); omitted `active` is
      # left untouched, so it keeps its current value (D-P12, key presence
      # here, rules in the model — C9).
      def update
        @product.assign_attributes(replacement_attributes)
        @product.save!
        render json: { data: serialize_product(@product) }
      end

      # DELETE /api/v1/products/:id -> 204, empty body (RF-6; permanent delete)
      def destroy
        @product.destroy!
        head :no_content
      end

      private

      def find_product!
        @product = Product.find_by!(id: params[:id])
      end

      def replacement_attributes
        attributes = product_params.to_h.symbolize_keys
        %i[name sku price stock description].each do |field|
          attributes[field] = nil unless attributes.key?(field)
        end
        attributes
      end

      # D-P10: bodies are wrapped in `{ "product": { … } }`. A missing, null,
      # or empty wrapper behaves like an empty product, so the model's rules
      # answer 422 — a client error never surfaces as 500.
      def product_params
        (params[:product].presence || ActionController::Parameters.new)
          .permit(:name, :description, :price, :stock, :sku, :active)
      end

      # The single product shape everywhere (plan API surface): `price` as a
      # 2-decimal string (D-P5, D-7). Reused by create/update/index (T4/T5).
      def serialize_product(product)
        {
          id: product.id,
          name: product.name,
          description: product.description,
          price: format('%.2f', product.price),
          stock: product.stock,
          sku: product.sku,
          active: product.active,
          created_at: product.created_at.utc.iso8601,
          updated_at: product.updated_at.utc.iso8601
        }
      end
    end
  end
end
