class Product < ApplicationRecord
  # Model-side normalizations (plan D-P8, C9): SKU uppercased and nil
  # description turned into "" before validating — never in the controller.
  before_validation :normalize_fields

  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, length: { maximum: 1000 }
  validates :price, numericality: { greater_than: 0 }
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sku, presence: true,
                  format: { with: /\A[A-Z0-9-]+\z/, allow_blank: true },
                  uniqueness: true
  validates :active, inclusion: { in: [true, false] }

  # RF-1 edge cases. `active`: ActiveRecord casts non-boolean input ("yes", 1)
  # to true, so the raw value must be checked. `price`: ActiveRecord rounds the
  # cast value to the column scale (9.999 -> 10.0) and PostgreSQL would round
  # silently at write time, so the raw value is checked too.
  validate :active_must_be_a_boolean
  validate :price_has_at_most_two_decimals

  private

  def normalize_fields
    self.sku = sku.to_s.upcase if sku.present?
    self.description = '' if description.nil?
  end

  def active_must_be_a_boolean
    # nil (`active: null`) and "" are reported by the inclusion validation.
    return if active.nil?

    # The column default reaches the model as the string "true".
    return if [true, false, 'true', 'false'].include?(active_before_type_cast)

    errors.add(:active, :inclusion)
  end

  def price_has_at_most_two_decimals
    # Non-numeric input converts to nil and is reported by the numericality
    # validation; the raw value keeps the decimals ActiveRecord would round away.
    raw = BigDecimal(price_before_type_cast.to_s, exception: false)
    return if raw.nil? || raw == raw.round(2)

    errors.add(:price, 'must have at most 2 decimal places')
  end
end
