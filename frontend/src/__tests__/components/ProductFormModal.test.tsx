// Form modal spec (T4+T5): edit pre-fill, string payload mechanics (D-P17),
// live mirror validation (RF-5/RF-6, D-12), and the save flow — confirmation
// before any request (RF-7), pending state, success feedback (RF-4), and the
// 422/404/other error contracts (RF-8/RF-9/RF-11). `fetch` is stubbed through
// vi.stubGlobal (D-P22); a fresh Response per call (a body reads once).
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import App from '../../App'
import { ProductFormModal } from '../../components/ProductFormModal'
import { ApiError } from '../../types/api'
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

/** Renders the modal with every callback spied; returns the spies. */
function renderModal(product: Product | undefined) {
  const onCancel = vi.fn()
  const onSaved = vi.fn()
  const onNotFound = vi.fn()
  const onError = vi.fn()
  render(
    <ProductFormModal
      product={product}
      onCancel={onCancel}
      onSaved={onSaved}
      onNotFound={onNotFound}
      onError={onError}
    />,
  )
  return { onCancel, onSaved, onNotFound, onError }
}

/** Clicks Save on the form and confirms in the dialog. */
async function saveAndConfirm(
  user: ReturnType<typeof userEvent.setup>,
): Promise<void> {
  await user.click(screen.getByRole('button', { name: 'Save' }))
  const dialog = screen.getByRole('dialog', { name: 'Confirm save' })
  await user.click(within(dialog).getByRole('button', { name: 'Save' }))
}

describe('ProductFormModal (form + validation)', () => {
  it('pre-fills the edit form, keeping price byte-identical', () => {
    renderModal(makeProduct())

    expect(screen.getByLabelText('Name')).toHaveValue('Mechanical keyboard')
    expect(screen.getByLabelText('Description')).toHaveValue('Quiet switches')
    expect(screen.getByLabelText('Price')).toHaveValue('49.99')
    expect(screen.getByLabelText('Stock')).toHaveValue('5')
    expect(screen.getByLabelText('SKU')).toHaveValue('KB-01')
    expect(screen.getByLabelText('Active')).toBeChecked()
  })

  it('blocks submission with the exact mirrored message while a field is invalid', async () => {
    const user = userEvent.setup()
    renderModal(makeProduct())

    const price = screen.getByLabelText('Price')
    await user.clear(price)
    await user.type(price, '9.999')

    expect(screen.getByText('must have at most 2 decimal places')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled()

    await user.click(screen.getByRole('button', { name: 'Save' }))
    expect(fetchMock).not.toHaveBeenCalled()
  })
})

describe('ProductFormModal (save flow)', () => {
  it('asks for confirmation before any request; cancel sends nothing and keeps the values', async () => {
    const user = userEvent.setup()
    const { onSaved } = renderModal(makeProduct())

    await user.click(screen.getByRole('button', { name: 'Save' }))

    expect(fetchMock).not.toHaveBeenCalled()
    const dialog = screen.getByRole('dialog', { name: 'Confirm save' })
    expect(within(dialog).getByText('Save this product?')).toBeInTheDocument()

    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }))

    expect(screen.queryByRole('dialog', { name: 'Confirm save' })).toBeNull()
    expect(screen.getByLabelText('Price')).toHaveValue('49.99')
    expect(fetchMock).not.toHaveBeenCalled()
    expect(onSaved).not.toHaveBeenCalled()
  })

  it('moves focus into the confirm dialog, Escape cancels, and the form is inert while it is open', async () => {
    const user = userEvent.setup()
    renderModal(makeProduct())

    await user.click(screen.getByRole('button', { name: 'Save' }))

    const dialog = screen.getByRole('dialog', { name: 'Confirm save' })
    expect(within(dialog).getByRole('button', { name: 'Save' })).toHaveFocus()
    expect(screen.getByRole('dialog', { name: 'Edit product' })).toHaveAttribute('inert')

    await user.keyboard('{Escape}')

    expect(screen.queryByRole('dialog', { name: 'Confirm save' })).toBeNull()
    expect(screen.getByRole('dialog', { name: 'Edit product' })).not.toHaveAttribute('inert')
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('on confirmation sends the PUT with price as the string and disables submit while pending', async () => {
    const user = userEvent.setup()
    const { onSaved } = renderModal(makeProduct())

    let resolveSave: ((value: Response | PromiseLike<Response>) => void) | undefined
    fetchMock.mockImplementation(
      () =>
        new Promise<Response>((resolve) => {
          resolveSave = resolve
        }),
    )

    const price = screen.getByLabelText('Price')
    await user.clear(price)
    await user.type(price, '59.50')
    await saveAndConfirm(user)

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

    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled()
    expect(onSaved).not.toHaveBeenCalled()

    resolveSave?.(jsonResponse({ data: makeProduct() }))
    await waitFor(() => expect(onSaved).toHaveBeenCalledTimes(1))
  })

  it('renders 422 details under their fields, unknown keys as a form-level message, values intact', async () => {
    const user = userEvent.setup()
    const { onSaved, onNotFound, onError } = renderModal(makeProduct())
    fetchMock.mockImplementation(() =>
      Promise.reject(
        new ApiError(422, 'unprocessable_entity', 'The product could not be saved.', {
          price: ['must be greater than 0'],
          base: ['is invalid'],
        }),
      ),
    )

    await saveAndConfirm(user)

    expect(await screen.findByText('must be greater than 0')).toBeInTheDocument()
    expect(screen.getByLabelText('Price')).toHaveAccessibleDescription(
      'must be greater than 0',
    )
    expect(screen.getByText('is invalid')).toBeInTheDocument()
    expect(screen.getByLabelText('Price')).toHaveValue('49.99')
    expect(screen.getByRole('button', { name: 'Save' })).toBeEnabled()
    expect(onSaved).not.toHaveBeenCalled()
    expect(onNotFound).not.toHaveBeenCalled()
    expect(onError).not.toHaveBeenCalled()
  })
})

describe('App save wiring (success, 404, network failure)', () => {
  it('success notifies, closes the modal, and refreshes the list', async () => {
    const user = userEvent.setup()
    fetchMock.mockImplementation((input) => {
      if (String(input).includes('/products/7')) {
        return jsonResponse({ data: makeProduct() })
      }
      return jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) })
    })

    render(<App />)
    const table = await screen.findByRole('table')
    await within(table).findByText('Mechanical keyboard')
    await user.click(within(table).getByRole('button', { name: 'Edit' }))
    // Background inert while the form modal is open (D-P19).
    expect(
      screen.getByRole('button', { name: 'New product' }).closest('[inert]'),
    ).not.toBeNull()

    await saveAndConfirm(user)

    expect(await screen.findByText('Product saved.')).toBeInTheDocument()
    expect(screen.queryByRole('dialog', { name: 'Edit product' })).toBeNull()
    // list GET + PUT + refresh GET
    expect(fetchMock).toHaveBeenCalledTimes(3)
  })

  it('404 on update informs, closes the form, and refreshes', async () => {
    const user = userEvent.setup()
    fetchMock.mockImplementation((input) => {
      if (String(input).includes('/products/7')) {
        return Promise.reject(new ApiError(404, 'not_found', 'Record not found'))
      }
      return jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) })
    })

    render(<App />)
    const table = await screen.findByRole('table')
    await within(table).findByText('Mechanical keyboard')
    await user.click(within(table).getByRole('button', { name: 'Edit' }))
    await saveAndConfirm(user)

    expect(
      await screen.findByText('This product no longer exists.'),
    ).toBeInTheDocument()
    expect(screen.queryByRole('dialog', { name: 'Edit product' })).toBeNull()
    expect(fetchMock).toHaveBeenCalledTimes(3)
  })

  it('network failure notifies, keeps the form open with the values intact', async () => {
    const user = userEvent.setup()
    fetchMock.mockImplementation((input) => {
      if (String(input).includes('/products/7')) {
        return Promise.reject(new TypeError('Failed to fetch'))
      }
      return jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) })
    })

    render(<App />)
    const table = await screen.findByRole('table')
    await within(table).findByText('Mechanical keyboard')
    await user.click(within(table).getByRole('button', { name: 'Edit' }))
    await saveAndConfirm(user)

    expect(
      await screen.findByText('Could not save the product.'),
    ).toBeInTheDocument()
    expect(screen.getByRole('dialog', { name: 'Edit product' })).toBeInTheDocument()
    expect(screen.getByLabelText('Price')).toHaveValue('49.99')
  })
})

describe('App modal wiring', () => {
  it('opens the modal from the list: edit pre-fills, New product starts empty', async () => {
    const user = userEvent.setup()
    fetchMock.mockImplementation(() =>
      jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) }),
    )

    render(<App />)
    const table = await screen.findByRole('table')
    await within(table).findByText('Mechanical keyboard')

    await user.click(within(table).getByRole('button', { name: 'Edit' }))
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByLabelText('Price')).toHaveValue('49.99')

    await user.click(screen.getByRole('button', { name: 'Cancel' }))
    expect(screen.queryByRole('dialog')).toBeNull()

    await user.click(screen.getByRole('button', { name: 'New product' }))
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByLabelText('Name')).toHaveValue('')
  })
})
