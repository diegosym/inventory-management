module Api
  module V1
    class ProductsController < ApplicationController
      # RF-5: unknown AND non-numeric :id answer 404, never 500 — find_by!
      # casts through the integer primary-key type ("abc" -> 0), so the raw
      # string never reaches the PostgreSQL driver. T4 reuses it for update.
      before_action :find_product!, only: %i[show destroy]

      # GET /api/v1/products/:id -> 200 { "data": { product } } (plan D-P5/D-7)
      def show
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
