import type { ProductActionsProps } from './ProductRow'

// Stacked-card presentation of a product below 768px (D-P21); the same
// actions as the table row, shown only on small screens via pure CSS on the
// wrapping element. `ProductActionsProps` is shared with ProductRow so both
// variants expose identical behaviour.
export function ProductCard({
  product,
  deletingId,
  onEdit,
  onDelete,
}: ProductActionsProps) {
  return (
    <li className="rounded-md border border-gray-300 p-4">
      <div className="flex items-start justify-between gap-2">
        <div>
          <p className="font-semibold">{product.name}</p>
          <p className="text-sm text-gray-600">SKU {product.sku}</p>
        </div>
        <span
          className={
            product.active
              ? 'rounded-full bg-brand/10 px-2 py-0.5 text-xs text-brand'
              : 'rounded-full bg-gray-200 px-2 py-0.5 text-xs text-gray-600'
          }
        >
          {product.active ? 'Active' : 'Inactive'}
        </span>
      </div>
      <p className="mt-2 text-sm text-gray-600">
        Price {product.price} · Stock {product.stock}
      </p>
      <div className="mt-3 flex gap-2">
        <button
          type="button"
          onClick={() => onEdit(product)}
          className="rounded-md border border-gray-300 px-2 py-1"
        >
          Edit
        </button>
        <button
          type="button"
          aria-label={`Delete ${product.name}`}
          disabled={deletingId === product.id}
          onClick={() => onDelete(product)}
          className="rounded-md border border-gray-300 px-2 py-1 disabled:cursor-not-allowed disabled:opacity-50"
        >
          Delete
        </button>
      </div>
    </li>
  )
}
