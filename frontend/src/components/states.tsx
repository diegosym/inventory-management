// Shared listing states (RF-3): loading, error with retry, and empty — the
// latter distinguishing an empty inventory from a search/filter with no
// matches.

export function LoadingState() {
  return (
    <p role="status" className="p-4 text-gray-600">
      Loading products...
    </p>
  )
}

interface ErrorStateProps {
  onRetry: () => void
}

export function ErrorState({ onRetry }: ErrorStateProps) {
  return (
    <div role="alert" className="p-4">
      <p className="text-danger">Could not load the products.</p>
      <button
        type="button"
        onClick={onRetry}
        className="mt-2 rounded-md bg-brand px-3 py-1.5 text-sm font-medium text-white hover:opacity-90"
      >
        Retry
      </button>
    </div>
  )
}

interface EmptyStateProps {
  /** True when a search term or an active filter is in effect. */
  filtered: boolean
}

export function EmptyState({ filtered }: EmptyStateProps) {
  return (
    <p role="status" className="p-4 text-gray-600">
      {filtered ? 'No products match your search.' : 'No products yet.'}
    </p>
  )
}
