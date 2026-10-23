class Product < ApplicationRecord
  # Spec 004 (D-P32): soft-deleted rows are invisible to every query by
  # construction; `Product.unscoped` is for tests/console only, never app code.
  default_scope { where(deleted_at: nil) }

  # Spec 004 T3 (RF-6/RF-7): the audit trail, written in the same transaction
  # as the change (D-P37). Readable from the console/tests; no `dependent:`
  # option — the audit outlives any future purge (D-P36, no FK).
  has_many :product_audits

  # The exactly-business fields an audit entry tracks (D-P38): `id`,
  # `created_at`, `updated_at`, and `deleted_at` are excluded from change
  # detection everywhere.
  AUDITED_FIELDS = %w[name description price stock sku active].freeze

  # Model-side normalizations (plan D-P8, C9): SKU uppercased and nil
  # description turned into "" before validating — never in the controller.
  before_validation :normalize_fields

  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, length: { maximum: 1000 }
  validates :price, numericality: { greater_than: 0 }
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # Uniqueness among visible rows only (spec 004 RF-4, D-P34): the `conditions:`
  # option is mandatory — Rails 8.1's validator builds from `klass.unscoped` and
  # ignores `default_scope`. Same rule, same message as spec 001 (D-6, C14).
  validates :sku, presence: true,
                  format: { with: /\A[A-Z0-9-]+\z/, allow_blank: true },
                  uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :active, inclusion: { in: [true, false] }

  # RF-1 edge cases. `active`: ActiveRecord casts non-boolean input ("yes", 1)
  # to true, so the raw value must be checked. `price`: ActiveRecord rounds the
  # cast value to the column scale (9.999 -> 10.0) and PostgreSQL would round
  # silently at write time, so the raw value is checked too.
  validate :active_must_be_a_boolean
  validate :price_has_at_most_two_decimals

  # Spec 004 T3 (RF-6, D-P37): callbacks run inside the save's transaction, so
  # a persisted change always has its entry and a rejected save has none.
  after_create :audit_creation
  after_update :audit_update

  # Spec 004 (D-P35): mark as deleted without destroying the row — only
  # `deleted_at` is written, no destroy callbacks. Called by the controller's
  # `destroy` action; the audit entry it produces is action `delete`.
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  private

  # D-P38 create: every business field of the persisted row with `from: null`
  # — the row's slice, not `saved_changes`, which omits attributes equal to
  # their column default. Values serialized like the API (2-decimal price).
  def audit_creation
    changes = AUDITED_FIELDS.to_h do |field|
      [field, { 'from' => nil, 'to' => serialize_audit_value(field, public_send(field)) }]
    end
    write_audit('create', changes)
  end

  # D-P37/D-P38 update: `deleted_at` becoming present is the soft delete —
  # action `delete` with no field values (D-16b); otherwise action `update`
  # with the business fields that changed on persisted values (D-16c), each
  # with its previous and new value. A no-op save (no business field changed)
  # writes nothing — the business-field filter, not callback suppression.
  def audit_update
    if saved_change_to_deleted_at? && deleted_at.present?
      return write_audit('delete', {})
    end

    changes = saved_changes.slice(*AUDITED_FIELDS)
    return if changes.empty?

    write_audit('update', changes.to_h { |field, (from, to)|
      [field, { 'from' => serialize_audit_value(field, from),
                'to' => serialize_audit_value(field, to) }]
    })
  end

  # D-15: the actor is the constant `"system"` for every change — API and
  # seeds alike — written explicitly, ready for a real actor if auth arrives.
  def write_audit(action, changes_data)
    product_audits.create!(action: action, changes_data: changes_data, actor: 'system')
  end

  # D-P38 value serialization: the API conventions the frontend mirrors
  # (D-7/D-12) — `price` as the 2-decimal string, everything else as its
  # persisted value (string / integer / boolean).
  def serialize_audit_value(field, value)
    field == 'price' ? format('%.2f', value) : value
  end

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
