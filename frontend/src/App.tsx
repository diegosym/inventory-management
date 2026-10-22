import { useState } from 'react'

import { deleteProduct } from './api/products'
import { ConfirmDialog } from './components/ConfirmDialog'
import { ProductFormModal } from './components/ProductFormModal'
import { ProductList } from './components/ProductList'
import { Notification } from './components/Notification'
import type { Notice } from './components/Notification'
import { useProducts } from './hooks/useProducts'
import { ApiError } from './types/api'
import type { Product } from './types/api'

// Modal state of the single view (RF-5, no router): closed, create, or edit
// with its target.
type ModalState =
  | { mode: 'closed' }
  | { mode: 'create' }
  | { mode: 'edit'; product: Product }

// Wires the listing hook (D-P16), the form modal (RF-5), and the persistent
// notification (C15) into one view.
function App() {
  const { products, meta, status, q, active, setQ, setActive, setPage, retry, refresh } =
    useProducts()
  const [modal, setModal] = useState<ModalState>({ mode: 'closed' })
  const [notice, setNotice] = useState<Notice | null>(null)
  const [deleting, setDeleting] = useState<Product | null>(null)
  const [deletePending, setDeletePending] = useState(false)

  // RF-7/RF-4: success notifies, closes, and refreshes.
  function handleSaved(): void {
    setNotice({ kind: 'success', message: 'Product saved.' })
    setModal({ mode: 'closed' })
    refresh()
  }

  // RF-9: the edit target is gone — inform, close, refresh.
  function handleNotFound(): void {
    setNotice({ kind: 'error', message: 'This product no longer exists.' })
    setModal({ mode: 'closed' })
    refresh()
  }

  // RF-11: any other failure keeps the form open and informs via notification.
  function handleError(message: string): void {
    setNotice({ kind: 'error', message })
  }

  // RF-10: confirm first (naming the product), then DELETE; 404 means the
  // target is already gone — inform and refresh; any other failure notifies
  // and leaves the list untouched (the dialog stays open for a retry).
  async function handleDeleteConfirm(): Promise<void> {
    if (deleting === null || deletePending) return
    const target = deleting
    setDeletePending(true)
    try {
      await deleteProduct(target.id)
      setNotice({ kind: 'success', message: 'Product deleted.' })
      setDeleting(null)
      refresh()
    } catch (error) {
      if (error instanceof ApiError && error.status === 404) {
        setNotice({ kind: 'error', message: 'This product was already deleted.' })
        setDeleting(null)
        refresh()
      } else {
        setNotice({ kind: 'error', message: 'Could not delete the product.' })
      }
    } finally {
      setDeletePending(false)
    }
  }

  return (
    <main className="mx-auto max-w-5xl space-y-6 bg-surface p-6">
      {/* Background inert while a modal or confirmation is open (D-P19, RF-12). */}
      <div inert={modal.mode !== 'closed' || deleting !== null} className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-brand">Inventory Management</h1>
          <button
            type="button"
            onClick={() => setModal({ mode: 'create' })}
            className="rounded-md bg-brand px-4 py-2 font-medium text-white hover:opacity-90"
          >
            New product
          </button>
        </div>
        <ProductList
          products={products}
          meta={meta}
          status={status}
          q={q}
          active={active}
          onQChange={setQ}
          onActiveChange={setActive}
          onPageChange={setPage}
          onRetry={retry}
          onEdit={(product) => setModal({ mode: 'edit', product })}
          onDelete={(product) => setDeleting(product)}
          deletingId={deleting === null ? null : deleting.id}
        />
      </div>
      {modal.mode === 'closed' ? null : (
        <ProductFormModal
          product={modal.mode === 'edit' ? modal.product : undefined}
          onCancel={() => setModal({ mode: 'closed' })}
          onSaved={handleSaved}
          onNotFound={handleNotFound}
          onError={handleError}
        />
      )}
      {notice === null ? null : (
        <Notification notice={notice} onDismiss={() => setNotice(null)} />
      )}
      {deleting === null ? null : (
        <ConfirmDialog
          title="Confirm delete"
          message={`Delete ${deleting.name}?`}
          confirmLabel="Delete"
          confirmDisabled={deletePending}
          onConfirm={handleDeleteConfirm}
          onCancel={() => setDeleting(null)}
        />
      )}
    </main>
  )
}

export default App
