import { useEffect, useState } from 'react'

import { listProducts } from '../api/products'
import type { ListingMeta, Product } from '../types/api'
import { useDebouncedValue } from './useDebouncedValue'

export type ProductsStatus = 'loading' | 'error' | 'ready'

// Server-side listing (C11): page, the debounced `q`, and the `active` filter
// are the only request parameters — nothing is searched, filtered, or
// paginated in the client. `retry` (RF-3) and `refresh` (RF-4) re-request the
// current parameters.
export function useProducts() {
  const [q, setQValue] = useState('')
  const [active, setActiveValue] = useState<boolean | undefined>(undefined)
  const [page, setPageValue] = useState(1)
  const [products, setProducts] = useState<Product[]>([])
  const [meta, setMeta] = useState<ListingMeta | null>(null)
  const [status, setStatus] = useState<ProductsStatus>('loading')
  const [nonce, setNonce] = useState(0)

  const debouncedQ = useDebouncedValue(q)

  // Interaction logic lives in the event handlers: searching or filtering
  // resets the listing to page 1 (RF-2).
  function setQ(value: string): void {
    setQValue(value)
    setPageValue(1)
  }

  function setActive(value: boolean | undefined): void {
    setActiveValue(value)
    setPageValue(1)
  }

  function setPage(value: number): void {
    setPageValue(value)
  }

  function refetch(): void {
    setNonce((current) => current + 1)
  }

  useEffect(() => {
    // A pending debounce means `q` is about to change: fetch once it settles,
    // so the page-1 reset never fires a request with the previous term.
    if (q !== debouncedQ) return

    let cancelled = false
    setStatus('loading')
    listProducts({ page, q: debouncedQ, active })
      .then((response) => {
        if (cancelled) return
        setProducts(response.data)
        setMeta(response.meta)
        setStatus('ready')
        // The server answers 200 (with empty data) for pages beyond the last
        // one (RF-4): clamp to the last valid page; changing `page` re-runs
        // this effect exactly once (total_pages never grows, so it settles).
        const lastPage = Math.max(response.meta.total_pages, 1)
        if (page > lastPage) setPageValue(lastPage)
      })
      .catch(() => {
        if (cancelled) return
        setStatus('error')
      })

    return () => {
      cancelled = true
    }
  }, [nonce, page, debouncedQ, active, q])

  return {
    products,
    meta,
    status,
    q,
    active,
    setQ,
    setActive,
    setPage,
    retry: refetch,
    refresh: refetch,
  }
}
