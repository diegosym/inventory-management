// Accessibility + responsive assertions (RF-12, NFR-5, D-P21): labels on
// every input, field errors linked programmatically (aria-invalid +
// aria-describedby), Escape closing without sending (form and both
// confirmations), every action a real <button>, and the CSS-only responsive
// split exposing the product in both the md+ table and the <md card list.
// `fetch` is stubbed through vi.stubGlobal (D-P22).
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import App from '../../App'
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

/** Renders the list with one product and waits until it is ready. */
async function renderList(): Promise<void> {
  fetchMock.mockImplementation(() =>
    jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) }),
  )
  render(<App />)
  await screen.findByRole('table')
}

describe('accessibility (RF-12)', () => {
  it('labels every form input and links the field error programmatically', async () => {
    const user = userEvent.setup()
    await renderList()
    await user.click(
      within(screen.getByRole('table')).getByRole('button', { name: 'Edit' }),
    )

    for (const label of ['Name', 'Description', 'Price', 'Stock', 'SKU', 'Active']) {
      expect(screen.getByLabelText(label)).toBeInTheDocument()
    }

    const price = screen.getByLabelText('Price')
    await user.clear(price)
    await user.type(price, '9.999')

    expect(price).toHaveAttribute('aria-invalid', 'true')
    expect(price).toHaveAccessibleDescription('must have at most 2 decimal places')
  })

  it('labels the toolbar controls', async () => {
    await renderList()

    expect(screen.getByLabelText('Search products by name')).toBeInTheDocument()
    expect(screen.getByLabelText('Filter by active status')).toBeInTheDocument()
  })

  it('Escape closes the form without sending anything', async () => {
    const user = userEvent.setup()
    await renderList()
    await user.click(
      within(screen.getByRole('table')).getByRole('button', { name: 'Edit' }),
    )
    expect(fetchMock).toHaveBeenCalledTimes(1)

    await user.keyboard('{Escape}')

    expect(screen.queryByRole('dialog', { name: 'Edit product' })).toBeNull()
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it('Escape closes the save confirmation without sending anything', async () => {
    const user = userEvent.setup()
    await renderList()
    await user.click(
      within(screen.getByRole('table')).getByRole('button', { name: 'Edit' }),
    )
    await user.click(screen.getByRole('button', { name: 'Save' }))
    expect(
      screen.getByRole('dialog', { name: 'Confirm save' }),
    ).toBeInTheDocument()

    await user.keyboard('{Escape}')

    expect(screen.queryByRole('dialog', { name: 'Confirm save' })).toBeNull()
    expect(screen.getByRole('dialog', { name: 'Edit product' })).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it('Escape closes the delete confirmation without sending anything', async () => {
    const user = userEvent.setup()
    await renderList()
    await user.click(
      within(screen.getByRole('table')).getByRole('button', {
        name: 'Delete Mechanical keyboard',
      }),
    )
    expect(
      screen.getByRole('dialog', { name: 'Confirm delete' }),
    ).toBeInTheDocument()

    await user.keyboard('{Escape}')

    expect(screen.queryByRole('dialog', { name: 'Confirm delete' })).toBeNull()
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })
})

describe('responsive split (D-P21, NFR-5)', () => {
  it('exposes the product in both the md+ table and the <md card list', async () => {
    await renderList()

    const table = screen.getByRole('table')
    expect(within(table).getByText('Mechanical keyboard')).toBeInTheDocument()
    expect(within(table).getByRole('button', { name: 'Edit' })).toBeInTheDocument()

    const cards = screen.getByRole('list')
    expect(within(cards).getByText('Mechanical keyboard')).toBeInTheDocument()
    expect(within(cards).getByRole('button', { name: 'Edit' })).toBeInTheDocument()
    expect(
      within(cards).getByRole('button', { name: 'Delete Mechanical keyboard' }),
    ).toBeInTheDocument()
  })

  it('every action is a real <button>, in table and cards alike', async () => {
    await renderList()

    const actions = [
      screen.getByRole('button', { name: 'New product' }),
      screen.getByRole('button', { name: 'Previous' }),
      screen.getByRole('button', { name: 'Next' }),
      within(screen.getByRole('table')).getByRole('button', { name: 'Edit' }),
      within(screen.getByRole('table')).getByRole('button', {
        name: 'Delete Mechanical keyboard',
      }),
      within(screen.getByRole('list')).getByRole('button', { name: 'Edit' }),
      within(screen.getByRole('list')).getByRole('button', {
        name: 'Delete Mechanical keyboard',
      }),
    ]

    for (const action of actions) {
      expect(action.tagName).toBe('BUTTON')
    }
  })

  it('keeps toolbar and pagination outside both variants (identical at every size)', async () => {
    await renderList()

    const table = screen.getByRole('table')
    const cards = screen.getByRole('list')
    for (const scope of [table, cards]) {
      expect(within(scope).queryByLabelText('Search products by name')).toBeNull()
      expect(within(scope).queryByRole('button', { name: 'Previous' })).toBeNull()
      expect(within(scope).queryByText(/Page \d+ of \d+/)).toBeNull()
    }
    expect(
      screen.getByRole('button', { name: 'Previous' }),
    ).toBeInTheDocument()
    await waitFor(() =>
      expect(
        screen.getByLabelText('Search products by name'),
      ).toBeInTheDocument(),
    )
  })
})
