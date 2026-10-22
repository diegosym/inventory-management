// Delete flow spec (T6, RF-10/RF-4): the confirmation names the product,
// confirming sends the DELETE with the row and confirm actions disabled
// while pending, success notifies and refreshes, 404 informs + refreshes,
// and any other failure notifies while the list stays intact. `fetch` is
// stubbed through vi.stubGlobal (D-P22); a fresh Response per call.
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import App from '../../App'
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

const ROW_BUTTON = 'button'
const ROW_NAME = 'Delete Mechanical keyboard'

/** Renders the list and opens the delete confirmation for the product. */
async function openDeleteDialog(
  user: ReturnType<typeof userEvent.setup>,
): Promise<HTMLElement> {
  render(<App />)
  const table = await screen.findByRole('table')
  await within(table).findByText('Mechanical keyboard')
  await user.click(within(table).getByRole(ROW_BUTTON, { name: ROW_NAME }))
  return screen.getByRole('dialog', { name: 'Confirm delete' })
}

describe('delete flow', () => {
  it('asks for confirmation naming the product; cancel sends nothing', async () => {
    const user = userEvent.setup()
    fetchMock.mockImplementation(() =>
      jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) }),
    )

    const dialog = await openDeleteDialog(user)

    expect(within(dialog).getByText('Delete Mechanical keyboard?')).toBeInTheDocument()

    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }))

    expect(screen.queryByRole('dialog', { name: 'Confirm delete' })).toBeNull()
    expect(fetchMock).toHaveBeenCalledTimes(1) // only the initial list GET
  })

  it('confirm sends the DELETE with both actions disabled while pending, notifies, and refreshes', async () => {
    const user = userEvent.setup()
    let resolveDelete: ((value: Response | PromiseLike<Response>) => void) | undefined
    fetchMock.mockImplementation((_input: unknown, init?: RequestInit) => {
      if (init?.method === 'DELETE') {
        return new Promise<Response>((resolve) => {
          resolveDelete = resolve
        })
      }
      return jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) })
    })

    const dialog = await openDeleteDialog(user)
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }))

    expect(fetchMock).toHaveBeenCalledTimes(2)
    const [url, init] = fetchMock.mock.calls[1]
    expect(new URL(String(url)).pathname).toBe('/api/v1/products/7')
    expect(init?.method).toBe('DELETE')
    // Row action and confirm action are disabled while pending (C15).
    expect(
      within(screen.getByRole('table')).getByRole(ROW_BUTTON, { name: ROW_NAME }),
    ).toBeDisabled()
    expect(
      within(screen.getByRole('dialog', { name: 'Confirm delete' })).getByRole('button', {
        name: 'Delete',
      }),
    ).toBeDisabled()

    resolveDelete?.(new Response(null, { status: 204 }))

    expect(await screen.findByText('Product deleted.')).toBeInTheDocument()
    expect(screen.queryByRole('dialog', { name: 'Confirm delete' })).toBeNull()
    // list GET + DELETE + refresh GET
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(3))
  })

  it('404 informs the product was already deleted and refreshes', async () => {
    const user = userEvent.setup()
    fetchMock.mockImplementation((_input: unknown, init?: RequestInit) => {
      if (init?.method === 'DELETE') {
        return Promise.reject(new ApiError(404, 'not_found', 'Record not found'))
      }
      return jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) })
    })

    const dialog = await openDeleteDialog(user)
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }))

    expect(
      await screen.findByText('This product was already deleted.'),
    ).toBeInTheDocument()
    expect(screen.queryByRole('dialog', { name: 'Confirm delete' })).toBeNull()
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(3))
  })

  it('any other failure notifies an error and keeps the list intact', async () => {
    const user = userEvent.setup()
    fetchMock.mockImplementation((_input: unknown, init?: RequestInit) => {
      if (init?.method === 'DELETE') {
        return Promise.reject(new TypeError('Failed to fetch'))
      }
      return jsonResponse({ data: [makeProduct()], meta: makeMeta(1, 1, 1) })
    })

    const dialog = await openDeleteDialog(user)
    await user.click(within(dialog).getByRole('button', { name: 'Delete' }))

    expect(await screen.findByText('Could not delete the product.')).toBeInTheDocument()
    // Dialog stays open for a retry, no refresh: the list is untouched.
    expect(screen.getByRole('dialog', { name: 'Confirm delete' })).toBeInTheDocument()
    expect(
      within(screen.getByRole('table')).getByText('Mechanical keyboard'),
    ).toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })
})
