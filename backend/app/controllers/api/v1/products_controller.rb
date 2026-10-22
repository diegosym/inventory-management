module Api
  module V1
    class ProductsController < ApplicationController
      # RF-5: unknown AND non-numeric :id answer 404, never 500 — find_by!
      # casts through the integer primary-key type ("abc" -> 0), so the raw
      # string never reaches the PostgreSQL driver. T4 reuses it for update.
      before_action :find_product!, only: %i[show update destroy]

      # GET /api/v1/products -> 200 { "data": [ … ], "meta": { … } } (RF-9…RF-14).
      # Pagination (fixed 10/page), `q` search, and `active` filter are resolved
      # in PostgreSQL and combined with the stable order
      # `created_at DESC, id DESC` (C11, RF-12); malformed query params answer
      # 422 with parameter-keyed details (RF-13, D-P11).
      def index
        param_errors = listing_param_errors
        if param_errors.any?
          return render_error(status: :unprocessable_entity,
                              code: 'validation_failed',
                              message: 'Validation failed',
                              details: param_errors)
        end

        scope = listing_scope
        total = scope.count
        current_page = params.key?(:page) ? params[:page].to_i : 1
        render json: {
          data: scope.limit(10).offset((current_page - 1) * 10)
                     .map { |product| serialize_product(product) },
          meta: { current_page: current_page, total_count: total,
                  total_pages: (total / 10.0).ceil }
        }
      end

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

      # RF-13 / D-P11: `page` must be a positive integer, `active` must be the
      # string "true" or "false", `q` must be a string. Errors are keyed by the
      # parameter name and reuse the standard 422 shape.
      def listing_param_errors
        errors = {}
        if params.key?(:page) && !params[:page].to_s.match?(/\A[1-9]\d*\z/)
          errors[:page] = ['must be a positive integer']
        end
        if params.key?(:active) && !%w[true false].include?(params[:active])
          errors[:active] = ['must be true or false']
        end
        errors[:q] = ['must be a string'] if params.key?(:q) && !params[:q].is_a?(String)
        errors
      end

      # The listing pipeline (plan pseudocode): filter and search in the
      # database (C11), stable order, then limit/offset by hand (D-P3, no
      # pagination gem). Whitespace-only `q` is no term (RF-10); `%`/`_` are
      # escaped so they match literally.
      def listing_scope
        scope = Product.all
        scope = scope.where(active: params[:active] == 'true') if params.key?(:active)
        term = params[:q].strip if params[:q].is_a?(String)
        if term.present?
          scope = scope.where('name ILIKE ?', "%#{Product.sanitize_sql_like(term)}%")
        end
        scope.order(created_at: :desc, id: :desc)
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
