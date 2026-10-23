// Mirror module (C14, D-9, D-P18): every message is a verbatim copy of what
// the spec-001 backend's Product model answers — verified against the running
// API (`bin/rails runner`). The backend is the final authority (C14).

// The form keeps every value as a string except `active` (D-P17): `price` and
// `stock` are never converted to numbers on this layer.
export interface ProductForm {
  name: string
  description: string
  price: string
  stock: string
  sku: string
  active: boolean
}

export type TextField = 'name' | 'description' | 'price' | 'stock' | 'sku'

export type ProductFormErrors = Partial<Record<keyof ProductForm, string>>

const TEXT_FIELDS: readonly TextField[] = [
  'name',
  'description',
  'price',
  'stock',
  'sku',
]

// Backend semantics (product.rb): SKU charset [A-Z0-9-]; Rails'
// is_number?/\A[+-]?(?:\d+|\d*\.\d+)\z/ (so "49." and "abc" are not numbers);
// integer check for `stock`.
const SKU_PATTERN = /^[A-Z0-9-]+$/
const NUMERIC_PATTERN = /^[+-]?(?:\d+|\d*\.\d+)$/
const INTEGER_PATTERN = /^[+-]?\d+$/

// D-6: the SKU is uppercased before validating and storing, mirroring the
// model's `normalize_fields`. Exported so the form uppercases on input too.
export function normalizeSku(sku: string): string {
  return sku.toUpperCase()
}

function charLength(text: string): number {
  // Ruby's String#length counts code points; Array.from matches it (C14).
  return Array.from(text).length
}

function hasMoreThanTwoDecimals(value: string): boolean {
  const fraction = value.split('.')[1]
  if (fraction === undefined) return false
  // Trailing zeros do not add scale: BigDecimal("1.100") == 1.1 is valid.
  return fraction.replace(/0+$/, '').length > 2
}

// Validates one form value against the backend's rules, returning the field's
// first backend message or null when valid. Values are trimmed first because
// the payload sends trimmed strings (the server validates what we send).
export function validateField(field: TextField, value: string): string | null {
  const text = value.trim()

  switch (field) {
    case 'name': {
      if (text === '') return "can't be blank"
      const length = charLength(text)
      if (length < 3) return 'is too short (minimum is 3 characters)'
      if (length > 100) return 'is too long (maximum is 100 characters)'
      return null
    }
    case 'description':
      return charLength(text) > 1000
        ? 'is too long (maximum is 1000 characters)'
        : null
    case 'price': {
      if (!NUMERIC_PATTERN.test(text)) return 'is not a number'
      if (Number(text) <= 0) return 'must be greater than 0'
      return hasMoreThanTwoDecimals(text)
        ? 'must have at most 2 decimal places'
        : null
    }
    case 'stock': {
      if (!NUMERIC_PATTERN.test(text)) return 'is not a number'
      if (!INTEGER_PATTERN.test(text)) return 'must be an integer'
      return Number(text) < 0 ? 'must be greater than or equal to 0' : null
    }
    case 'sku': {
      if (text === '') return "can't be blank"
      return SKU_PATTERN.test(normalizeSku(text)) ? null : 'is invalid'
    }
  }
}

// Validates the whole form; `active` needs no runtime branch — ProductForm
// types it as boolean, the only shape the checkbox can hold and the payload
// can send (RF-6).
export function validateProduct(values: ProductForm): ProductFormErrors {
  const errors: ProductFormErrors = {}
  for (const field of TEXT_FIELDS) {
    const message = validateField(field, values[field])
    if (message !== null) errors[field] = message
  }
  return errors
}
