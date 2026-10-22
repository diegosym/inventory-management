import type { FormEvent } from 'react'
import { useState } from 'react'

import { createProduct, updateProduct } from '../api/products'
import type { Product, ProductPayload } from '../types/api'
import {
  normalizeSku,
  validateProduct,
  type ProductForm,
  type TextField,
} from '../validators/product'
import { Field } from './Field'

interface ProductFormModalProps {
  /** The product being edited; undefined starts the create mode (RF-5). */
  product: Product | undefined
  onCancel: () => void
  /** Called after a successful save; App closes the modal and refreshes. */
  onSaved: () => void
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

// Single create/edit form over the list (RF-5, no router). Live mirror
// validation (RF-6) blocks submission; the save flow around the request
// (confirmation, notifications, 422/404 contracts) lands in T5.
export function ProductFormModal({
  product,
  onCancel,
  onSaved,
}: ProductFormModalProps) {
  const [values, setValues] = useState<ProductForm>(() => initialValues(product))
  const [saveError, setSaveError] = useState<string | null>(null)

  // RF-6: mirrored validation derived during render (C14/D-12); the submit
  // button stays disabled while any field carries a backend message.
  const errors = validateProduct(values)
  const isValid = Object.keys(errors).length === 0

  function setField(field: TextField, value: string): void {
    const next =
      field === 'sku' ? normalizeSku(value) : field === 'price' ? sanitizeDecimal(value) : value
    setValues((current) => ({ ...current, [field]: next }))
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault()
    if (!isValid) return

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
      // Minimal alert for T4; T5 replaces this with the 422/404/other
      // contracts of RF-8/RF-9/RF-11.
      setSaveError(
        error instanceof Error ? error.message : 'Could not save the product.',
      )
    }
  }

  return (
    <div className="fixed inset-0 z-10 flex items-center justify-center bg-black/40 p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="product-form-title"
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
          {saveError === null ? null : (
            <p role="alert" className="text-sm text-danger">
              {saveError}
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
              disabled={!isValid}
              className="rounded-md bg-brand px-4 py-2 font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
            >
              Save
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
