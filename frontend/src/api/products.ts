import {
  ApiError,
  type ApiErrorBody,
  type ListingResponse,
  type ProductPayload,
  type ProductResponse,
} from '../types/api'

// Browser-reachable backend URL (D-P14, provided via compose env, NFR-4/D-11).
const BASE_URL = import.meta.env.VITE_API_BASE_URL

export interface ListProductsParams {
  page?: number
  q?: string
  active?: boolean
}

// One private helper for every call (D-P15, D-10 plain fetch): non-2xx answers
// are parsed into ApiError (C10); network rejections propagate untouched.
async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, init)

  if (!response.ok) {
    let body: ApiErrorBody | null = null
    try {
      body = (await response.json()) as ApiErrorBody
    } catch {
      body = null
    }
    throw new ApiError(
      response.status,
      body?.error?.code ?? 'error',
      body?.error?.message ?? response.statusText,
      body?.error?.details,
    )
  }

  // DELETE answers 204 with no body (D-P15 API surface).
  if (response.status === 204) return undefined as T
  return (await response.json()) as T
}

export function listProducts(
  params: ListProductsParams = {},
): Promise<ListingResponse> {
  const query = new URLSearchParams()
  if (params.page !== undefined) query.set('page', String(params.page))
  if (params.q !== undefined) query.set('q', params.q)
  if (params.active !== undefined) query.set('active', String(params.active))
  const qs = query.toString()
  return request<ListingResponse>(
    `/api/v1/products${qs === '' ? '' : `?${qs}`}`,
  )
}

export function createProduct(
  payload: ProductPayload,
): Promise<ProductResponse> {
  return request<ProductResponse>('/api/v1/products', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ product: payload }),
  })
}

export function updateProduct(
  id: number,
  payload: ProductPayload,
): Promise<ProductResponse> {
  return request<ProductResponse>(`/api/v1/products/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ product: payload }),
  })
}

export async function deleteProduct(id: number): Promise<void> {
  await request<void>(`/api/v1/products/${id}`, { method: 'DELETE' })
}
