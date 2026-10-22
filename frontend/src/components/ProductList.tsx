import type { ProductsStatus } from '../hooks/useProducts'
import type { ListingMeta, Product } from '../types/api'
import { EmptyState, ErrorState, LoadingState } from './states'

interface ProductListProps {
  products: Product[]
  meta: ListingMeta | null
  status: ProductsStatus
  q: string
  active: boolean | undefined
  onQChange: (q: string) => void
  onActiveChange: (active: boolean | undefined) => void
  onPageChange: (page: number) => void
  onRetry: () => void
  onEdit: (product: Product) => void
  onDelete: (product: Product) => void
  /** Id of the row whose delete is in flight (its action is disabled). */
  deletingId: number | null
}

// Toolbar + states + rows + pagination. Pagination and filtering are the
// server's job (C11): this component only mirrors `meta` and forwards the
// user's events.
export function ProductList({
  products,
  meta,
  status,
  q,
  active,
  onQChange,
  onActiveChange,
  onPageChange,
  onRetry,
  onEdit,
  onDelete,
  deletingId,
}: ProductListProps) {
  const currentPage = meta?.current_page ?? 1
  const totalPages = meta?.total_pages ?? 1
  const totalCount = meta?.total_count ?? 0
  const filtered = q.trim() !== '' || active !== undefined

  return (
    <section className="space-y-4">
      <div className="flex flex-col gap-2 md:flex-row">
        <input
          type="search"
          aria-label="Search products by name"
          placeholder="Search by name"
          value={q}
          onChange={(event) => onQChange(event.target.value)}
          className="w-full rounded-md border border-gray-300 px-3 py-2 md:max-w-xs"
        />
        <select
          aria-label="Filter by active status"
          value={active === undefined ? '' : String(active)}
          onChange={(event) =>
            onActiveChange(
              event.target.value === ''
                ? undefined
                : event.target.value === 'true',
            )
          }
          className="rounded-md border border-gray-300 px-3 py-2"
        >
          <option value="">All</option>
          <option value="true">Active only</option>
          <option value="false">Inactive only</option>
        </select>
      </div>

      {status === 'loading' ? (
        <LoadingState />
      ) : status === 'error' ? (
        <ErrorState onRetry={onRetry} />
      ) : products.length === 0 ? (
        <EmptyState filtered={filtered} />
      ) : (
        <>
          <table className="w-full border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-gray-300 text-gray-600">
                <th className="py-2 pr-4 font-semibold">Name</th>
                <th className="py-2 pr-4 font-semibold">SKU</th>
                <th className="py-2 pr-4 font-semibold">Price</th>
                <th className="py-2 pr-4 font-semibold">Stock</th>
                <th className="py-2 pr-4 font-semibold">Active</th>
                <th className="py-2 pr-4 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {products.map((product) => (
                <tr key={product.id} className="border-b border-gray-200">
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
              ))}
            </tbody>
          </table>

          <nav
            aria-label="Pagination"
            className="flex items-center justify-between text-sm text-gray-600"
          >
            <span>
              {totalCount === 1 ? '1 product' : `${totalCount} products`}
            </span>
            <div className="flex items-center gap-3">
              <button
                type="button"
                disabled={currentPage <= 1}
                onClick={() => onPageChange(currentPage - 1)}
                className="rounded-md border border-gray-300 px-3 py-1.5 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Previous
              </button>
              <span>
                Page {currentPage} of {totalPages}
              </span>
              <button
                type="button"
                disabled={currentPage >= totalPages}
                onClick={() => onPageChange(currentPage + 1)}
                className="rounded-md border border-gray-300 px-3 py-1.5 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Next
              </button>
            </div>
          </nav>
        </>
      )}
    </section>
  )
}
