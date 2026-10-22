// Form modal spec (T4): edit pre-fill, string payload mechanics (D-P17), and
// live mirror validation blocking submission (RF-5/RF-6, D-12). `fetch` is
// stubbed through vi.stubGlobal like the list spec (D-P22); a fresh Response
// per call because a body can only be read once.
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import App from '../../App'
import { ProductFormModal } from '../../components/ProductFormModal'
import type { ListingMeta, Product } from '../../types/api'

function makeProduct(overrides: Partial<Product> = {}): Product {
  return {
    id: 7,
    name: 'Mechanical keyboard',
    description: 'Quiet switches',
    price: '49.99',
    stock: 5,
    sku: 'KB-01',
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

function jsonResponse(body: unknown): Promise<Response> {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }),
  )
}

const fetchMock = vi.fn()

beforeEach(() => {
  fetchMock.mockReset()
  vi.stubGlobal('fetch', fetchMock)
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('ProductFormModal', () => {
  it('pre-fills the edit form, keeping price byte-identical', () => {
    render(
      <ProductFormModal
        product={makeProduct()}
        onCancel={vi.fn()}
        onSaved={vi.fn()}
      />,
    )

    expect(screen.getByLabelText('Name')).toHaveValue('Mechanical keyboard')
    expect(screen.getByLabelText('Description')).toHaveValue('Quiet switches')
    expect(screen.getByLabelText('Price')).toHaveValue('49.99')
    expect(screen.getByLabelText('Stock')).toHaveValue('5')
    expect(screen.getByLabelText('SKU')).toHaveValue('KB-01')
    expect(screen.getByLabelText('Active')).toBeChecked()
  })

  it('sends the PUT with price as the decimal string (D-P17 round-trip)', async () => {
    const user = userEvent.setup()
    const onSaved = vi.fn()
    fetchMock.mockImplementation(() => jsonResponse({ data: makeProduct() }))

    render(
      <ProductFormModal
        product={makeProduct()}
        onCancel={vi.fn()}
        onSaved={onSaved}
      />,
    )

    const price = screen.getByLabelText('Price')
    await user.clear(price)
    await user.type(price, '59.50')
    await user.click(screen.getByRole('button', { name: 'Save' }))

    expect(fetchMock).toHaveBeenCalledTimes(1)
    const [url, init] = fetchMock.mock.calls[0]
    expect(new URL(String(url)).pathname).toBe('/api/v1/products/7')
    expect(init?.method).toBe('PUT')

    const body = JSON.parse(String(init?.body))
    expect(body.product.price).toBe('59.50')
    expect(typeof body.product.price).toBe('string')
    expect(body.product.stock).toBe('5')
    expect(body.product.active).toBe(true)
    expect(body.product.sku).toBe('KB-01')

    await waitFor(() => expect(onSaved).toHaveBeenCalledTimes(1))
  })

  it('blocks submission with the exact mirrored message while a field is invalid', async () => {
    const user = userEvent.setup()

    render(
      <ProductFormModal
        product={makeProduct()}
        onCancel={vi.fn()}
        onSaved={vi.fn()}
      />,
    )

    const price = screen.getByLabelText('Price')
    await user.clear(price)
    await user.type(price, '9.999')

    expect(screen.getByText('must have at most 2 decimal places')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled()

    await user.click(screen.getByRole('button', { name: 'Save' }))
    expect(fetchMock).not.toHaveBeenCalled()
  })
})

describe('App modal wiring', () => {
  it('opens the modal from the list: edit pre-fills, New product starts empty', async () => {
    const user = userEvent.setup()
    fetchMock.mockImplementation(() =>
      jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) }),
    )

    render(<App />)
    await screen.findByText('Mechanical keyboard')

    await user.click(screen.getByRole('button', { name: 'Edit' }))
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByLabelText('Price')).toHaveValue('49.99')

    await user.click(screen.getByRole('button', { name: 'Cancel' }))
    expect(screen.queryByRole('dialog')).toBeNull()

    await user.click(screen.getByRole('button', { name: 'New product' }))
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByLabelText('Name')).toHaveValue('')
  })
})
