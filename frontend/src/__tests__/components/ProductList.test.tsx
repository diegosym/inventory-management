// Component spec for the listing flow (T3): App wiring + useProducts +
// ProductList, with `fetch` stubbed through vi.stubGlobal (D-P22). Every
// page/q/active change must produce a server request (C11, no client-side
// filtering), so the request URL is part of the asserted contract.
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import App from '../../App'
import type { ListingMeta, Product } from '../../types/api'

function makeProduct(id: number, overrides: Partial<Product> = {}): Product {
  return {
    id,
    name: `Product ${id}`,
    description: '',
    price: '12.34',
    stock: 3,
    sku: `SKU-${id}`,
    active: true,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    ...overrides,
  }
}

function makeMeta(
  current_page: number,
  total_count: number,
  total_pages: number,
): ListingMeta {
  return { current_page, total_count, total_pages }
}

function listingResponse(data: Product[], meta: ListingMeta): Promise<Response> {
  return Promise.resolve(
    new Response(JSON.stringify({ data, meta }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }),
  )
}

const fetchMock = vi.fn()

/** URL of the request at `index` (the API layer passes an absolute URL string). */
function requestUrl(index: number): URL {
  return new URL(String(fetchMock.mock.calls[index]?.[0]))
}

beforeEach(() => {
  fetchMock.mockReset()
  vi.stubGlobal('fetch', fetchMock)
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('ProductList (listing flow)', () => {
  it('shows the loading state while the list request is pending', () => {
    fetchMock.mockReturnValue(new Promise<Response>(() => {}))

    render(<App />)

    expect(screen.getByRole('status')).toHaveTextContent('Loading products...')
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it('shows the error state and re-requests when retry is clicked', async () => {
    const user = userEvent.setup()
    fetchMock
      .mockRejectedValueOnce(new TypeError('network down'))
      .mockResolvedValueOnce(
        listingResponse([makeProduct(1)], makeMeta(1, 1, 1)),
      )

    render(<App />)

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Could not load the products.',
    )
    expect(fetchMock).toHaveBeenCalledTimes(1)

    await user.click(screen.getByRole('button', { name: 'Retry' }))

    expect(await screen.findByText('Product 1')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it('shows the empty-inventory state when there are no products and no filter', async () => {
    // A fresh Response per call: a body can only be read once.
    fetchMock.mockImplementation(() => listingResponse([], makeMeta(1, 0, 0)))

    render(<App />)

    expect(await screen.findByText('No products yet.')).toBeInTheDocument()
  })

  it('shows the no-matches state when a filter yields nothing (filter sent to the API)', async () => {
    const user = userEvent.setup()
    // A fresh Response per call: a body can only be read once.
    fetchMock.mockImplementation(() => listingResponse([], makeMeta(1, 0, 0)))

    render(<App />)
    await screen.findByText('No products yet.')

    await user.selectOptions(
      screen.getByLabelText('Filter by active status'),
      'true',
    )

    expect(await screen.findByText('No products match your search.')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledTimes(2)
    // C11: the filter travels as a server parameter; nothing is filtered here.
    expect(requestUrl(1).searchParams.get('active')).toBe('true')
  })

  it('drives the pagination controls from the stubbed meta', async () => {
    fetchMock.mockResolvedValue(
      listingResponse([makeProduct(1)], makeMeta(2, 15, 2)),
    )

    render(<App />)

    expect(await screen.findByText('Page 2 of 2')).toBeInTheDocument()
    expect(screen.getByText('15 products')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Previous' })).toBeEnabled()
    expect(screen.getByRole('button', { name: 'Next' })).toBeDisabled()
  })

  it('debounces q and resets the request to page 1 with the term', async () => {
    const user = userEvent.setup()
    fetchMock
      .mockResolvedValueOnce(
        listingResponse([makeProduct(1), makeProduct(2)], makeMeta(1, 15, 2)),
      )
      .mockResolvedValueOnce(listingResponse([makeProduct(3)], makeMeta(2, 15, 2)))
      .mockResolvedValueOnce(listingResponse([], makeMeta(1, 0, 0)))

    render(<App />)
    await screen.findByText('Page 1 of 2')

    await user.click(screen.getByRole('button', { name: 'Next' }))
    await screen.findByText('Page 2 of 2')
    expect(requestUrl(1).searchParams.get('page')).toBe('2')

    await user.type(screen.getByLabelText('Search products by name'), 'keyboard')

    // Debounce: no new request before the term settles (~300 ms).
    expect(fetchMock).toHaveBeenCalledTimes(2)
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(3), {
      timeout: 2000,
    })

    const last = requestUrl(2)
    expect(last.pathname).toBe('/api/v1/products')
    expect(last.searchParams.get('page')).toBe('1')
    expect(last.searchParams.get('q')).toBe('keyboard')
  })
})
