import type { Product } from '../types/api'

export interface ProductActionsProps {
  product: Product
  /** Id of the row whose delete is in flight (its action is disabled). */
  deletingId: number | null
  onEdit: (product: Product) => void
  onDelete: (product: Product) => void
}

// Table presentation of a product for the md+ table (D-P21); visible only
// from 768px up via pure CSS on the wrapping element.
export function ProductRow({
  product,
  deletingId,
  onEdit,
  onDelete,
}: ProductActionsProps) {
  return (
    <tr className="border-b border-gray-200">
      <td className="py-2 pr-4">{product.name}</td>
      <td className="py-2 pr-4">{product.sku}</td>
      <td className="py-2 pr-4">{product.price}</td>
      <td className="py-2 pr-4">{product.stock}</td>
      <td className="py-2 pr-4">{product.active ? 'Yes' : 'No'}</td>
      <td className="py-2 pr-4">
        <div className="flex gap-2">
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
      </td>
    </tr>
  )
}
