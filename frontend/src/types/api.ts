// Contract types for the frozen spec-001 API (D-7, D-9). Explicit types
// everywhere; no `any` (C13 / NFR-2).

export interface Product {
  id: number
  name: string
  description: string
  /** Decimal string with 2 places (e.g. "49.99") — never a JS number (D-5). */
  price: string
  stock: number
  sku: string
  active: boolean
  created_at: string
  updated_at: string
}

export interface ListingMeta {
  current_page: number
  total_count: number
  total_pages: number
}

export interface ListingResponse {
  data: Product[]
  meta: ListingMeta
}

export interface ProductResponse {
  data: Product
}

/** POST/PUT body: trimmed strings for every field, `active` a real boolean (D-9). */
export interface ProductPayload {
  name: string
  description: string
  price: string
  stock: string
  sku: string
  active: boolean
}

/** The single error shape (C10, D-7); `details` only on 422, keyed by field. */
export interface ApiErrorBody {
  error: {
    code: string
    message: string
    details?: Record<string, string[]>
  }
}

/** Every non-2xx answer becomes one of these (C10: 404/422/500). */
export class ApiError extends Error {
  readonly status: number
  readonly code: string
  readonly details?: Record<string, string[]>

  constructor(
    status: number,
    code: string,
    message: string,
    details?: Record<string, string[]>,
  ) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
    this.details = details
  }
}
