import { ProductList } from './components/ProductList'
import { useProducts } from './hooks/useProducts'

// Wires the listing hook (D-P16) into the list view; the hook's `refresh`
// stays available for the mutation flows (RF-4, tasks T4+).
function App() {
  const { products, meta, status, q, active, setQ, setActive, setPage, retry } =
    useProducts()

  return (
    <main className="mx-auto max-w-5xl space-y-6 bg-surface p-6">
      <h1 className="text-2xl font-bold text-brand">Inventory Management</h1>
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
      />
    </main>
  )
}

export default App
