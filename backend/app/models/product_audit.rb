# Spec 004 T3 (D-P36): immutable audit record — one row per successful product
# change (create / update / soft delete), written by Product's in-transaction
# callbacks (D-P37). Internal-only: no endpoint, no serializer (RF-8).
class ProductAudit < ApplicationRecord
  validates :action, inclusion: { in: %w[create update delete] }

  # Entries are write-once: nothing in the app updates or destroys them.
  def update(...)  = not_immutable!
  def update!(...) = not_immutable!
  def destroy      = not_immutable!
  def destroy!     = not_immutable!
  def touch(...)   = not_immutable!

  private

  def not_immutable!
    raise ActiveRecord::RecordNotSaved, 'ProductAudit entries are immutable'
  end
end
