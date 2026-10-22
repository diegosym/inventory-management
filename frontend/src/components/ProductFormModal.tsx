import type { FormEvent } from 'react'
import { useState } from 'react'

import { createProduct, updateProduct } from '../api/products'
import { ApiError } from '../types/api'
import type { Product, ProductPayload } from '../types/api'
import {
  normalizeSku,
  validateProduct,
  type ProductForm,
  type ProductFormErrors,
  type TextField,
} from '../validators/product'
import { ConfirmDialog } from './ConfirmDialog'
import { Field } from './Field'

interface ProductFormModalProps {
  /** The product being edited; undefined starts the create mode (RF-5). */
  product: Product | undefined
  onCancel: () => void
  /** Success: App notifies, closes, and refreshes (RF-7/RF-4). */
  onSaved: () => void
  /** 404 on update: App informs, closes, and refreshes (RF-9). */
  onNotFound: () => void
  /** Any other failure: App shows the error notification (RF-11). */
  onError: (message: string) => void
}

// D-P17: price and stock stay strings end to end — the edit pre-fill passes
// the decimal string through untouched (never a JS number) and the payload
// sends trimmed strings; the server casts.
function initialValues(product: Product | undefined): ProductForm {
  if (product === undefined) {
    return {
      name: '',
      description: '',
      price: '',
      stock: '',
      sku: '',
      active: true,
    }
  }
  return {
    name: product.name,
    description: product.description,
    price: product.price,
    stock: String(product.stock),
    sku: product.sku,
    active: product.active,
  }
}

// D-P17 typing rule: keep only what conforms to /^\d*(\.\d*)?$/ (digits and
// at most one dot); whatever still fails is reported by the mirror validator.
function sanitizeDecimal(value: string): string {
  return value.replace(/[^\d.]/g, '').replace(/(\.\d*)\./g, '$1')
}

function isTextField(key: string): key is TextField {
  return (
    key === 'name' ||
    key === 'description' ||
    key === 'price' ||
    key === 'stock' ||
    key === 'sku'
  )
}

// Single create/edit form over the list (RF-5, no router). Live mirror
// validation (RF-6) blocks submission; the save flow asks for confirmation
// before sending (RF-7) and applies the 422/404/other contracts (RF-8/9/11).
export function ProductFormModal({
  product,
  onCancel,
  onSaved,
  onNotFound,
  onError,
}: ProductFormModalProps) {
  const [values, setValues] = useState<ProductForm>(() => initialValues(product))
  const [confirming, setConfirming] = useState(false)
  const [pending, setPending] = useState(false)
  const [serverErrors, setServerErrors] = useState<ProductFormErrors>({})
  const [formError, setFormError] = useState<string | null>(null)

  // RF-6: mirrored validation derived during render (C14/D-12), overridden
  // per field by the server's 422 details (RF-8) while they apply.
  const errors = { ...validateProduct(values), ...serverErrors }
  const isValid = Object.keys(validateProduct(values)).length === 0

  function setField(field: TextField, value: string): void {
    const next =
      field === 'sku' ? normalizeSku(value) : field === 'price' ? sanitizeDecimal(value) : value
    setValues((current) => ({ ...current, [field]: next }))
    // Editing a field invalidates the server's message for it; the mirror
    // takes over again on the next render.
    setServerErrors((current) => {
      if (current[field] === undefined) return current
      const rest = { ...current }
      delete rest[field]
      return rest
    })
  }

  // RF-7: the form only opens the confirmation; nothing is sent yet.
  function handleSubmit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault()
    if (!isValid || pending) return
    setServerErrors({})
    setFormError(null)
    setConfirming(true)
  }

  // RF-8: details keyed by a known field render under it; any other key
  // (e.g. `base`) becomes a form-level message.
  function applyServerErrors(details: Record<string, string[]> | undefined): void {
    if (details === undefined) {
      setFormError('The product could not be saved.')
      return
    }
    const fieldErrors: ProductFormErrors = {}
    const unknown: string[] = []
    for (const [key, messages] of Object.entries(details)) {
      const message = messages[0] ?? 'is invalid'
      if (isTextField(key)) fieldErrors[key] = message
      else unknown.push(message)
    }
    setServerErrors(fieldErrors)
    setFormError(unknown.length > 0 ? unknown.join(' ') : null)
  }

  async function handleConfirm(): Promise<void> {
    setConfirming(false)
    setPending(true)

    const payload: ProductPayload = {
      name: values.name.trim(),
      description: values.description.trim(),
      price: values.price.trim(),
      stock: values.stock.trim(),
      sku: normalizeSku(values.sku.trim()),
      active: values.active,
    }

    try {
      if (product === undefined) {
        await createProduct(payload)
      } else {
        await updateProduct(product.id, payload)
      }
      onSaved()
    } catch (error) {
      if (error instanceof ApiError && error.status === 422) {
        applyServerErrors(error.details)
      } else if (error instanceof ApiError && error.status === 404) {
        onNotFound()
      } else {
        onError(
          error instanceof ApiError ? error.message : 'Could not save the product.',
        )
      }
    } finally {
      setPending(false)
    }
  }

  return (
    <>
      <div className="fixed inset-0 z-10 flex items-center justify-center bg-black/40 p-4">
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="product-form-title"
          inert={confirming}
          className="w-full max-w-lg rounded-lg bg-white p-6 shadow-lg"
        >
          <h2 id="product-form-title" className="text-xl font-bold">
            {product === undefined ? 'New product' : 'Edit product'}
          </h2>
          <form onSubmit={handleSubmit} className="mt-4 space-y-4">
            <Field
              id="product-name"
              label="Name"
              value={values.name}
              error={errors.name ?? null}
              onChange={(value) => setField('name', value)}
            />
            <Field
              id="product-description"
              label="Description"
              value={values.description}
              error={errors.description ?? null}
              onChange={(value) => setField('description', value)}
              multiline
              placeholder="Optional"
            />
            <Field
              id="product-price"
              label="Price"
              value={values.price}
              error={errors.price ?? null}
              onChange={(value) => setField('price', value)}
              inputMode="decimal"
              placeholder="0.00"
            />
            <Field
              id="product-stock"
              label="Stock"
              value={values.stock}
              error={errors.stock ?? null}
              onChange={(value) => setField('stock', value)}
              placeholder="0"
            />
            <Field
              id="product-sku"
              label="SKU"
              value={values.sku}
              error={errors.sku ?? null}
              onChange={(value) => setField('sku', value)}
            />
            <div className="flex items-center gap-2">
              <input
                id="product-active"
                type="checkbox"
                checked={values.active}
                onChange={(event) =>
                  setValues((current) => ({ ...current, active: event.target.checked }))
                }
              />
              <label htmlFor="product-active" className="text-sm font-medium">
                Active
              </label>
            </div>
            {formError === null ? null : (
              <p role="alert" className="text-sm text-danger">
                {formError}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={onCancel}
                className="rounded-md border border-gray-300 px-4 py-2"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={!isValid || pending}
                className="rounded-md bg-brand px-4 py-2 font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
              >
                Save
              </button>
            </div>
          </form>
        </div>
      </div>
      {confirming ? (
        <ConfirmDialog
          title="Confirm save"
          message="Save this product?"
          confirmLabel="Save"
          onConfirm={handleConfirm}
          onCancel={() => setConfirming(false)}
        />
      ) : null}
    </>
  )
}
