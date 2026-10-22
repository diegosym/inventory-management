import { useState } from 'react'

import { ProductFormModal } from './components/ProductFormModal'
import { ProductList } from './components/ProductList'
import { useProducts } from './hooks/useProducts'
import type { Product } from './types/api'

// Modal state of the single view (RF-5, no router): closed, create, or edit
// with its target.
type ModalState =
  | { mode: 'closed' }
  | { mode: 'create' }
  | { mode: 'edit'; product: Product }

// Wires the listing hook (D-P16) and the form modal (RF-5) into one view.
function App() {
  const { products, meta, status, q, active, setQ, setActive, setPage, retry, refresh } =
    useProducts()
  const [modal, setModal] = useState<ModalState>({ mode: 'closed' })

  function handleSaved(): void {
    setModal({ mode: 'closed' })
    refresh()
  }

  return (
    <main className="mx-auto max-w-5xl space-y-6 bg-surface p-6">
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
      />
      {modal.mode === 'closed' ? null : (
        <ProductFormModal
          product={modal.mode === 'edit' ? modal.product : undefined}
          onCancel={() => setModal({ mode: 'closed' })}
          onSaved={handleSaved}
        />
      )}
    </main>
  )
}

export default App
