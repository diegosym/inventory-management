import { describe, expect, it } from 'vitest'

import {
  normalizeSku,
  validateField,
  validateProduct,
  type ProductForm,
} from '../../validators/product'

// Every message below is asserted against the live backend contract (C14/D-9:
// the mirror copies product.rb's messages verbatim — verified with
// `bin/rails runner` against the running spec-001 API).
function validForm(): ProductForm {
  return {
    name: 'Keyboard',
    description: 'Mechanical keyboard',
    price: '49.99',
    stock: '12',
    sku: 'KB-01',
    active: true,
  }
}

describe('validateField — name', () => {
  it('rejects a blank name', () => {
    expect(validateField('name', '')).toBe("can't be blank")
  })

  it('rejects a 2-character name', () => {
    expect(validateField('name', 'ab')).toBe(
      'is too short (minimum is 3 characters)',
    )
  })

  it('accepts a 3-character name', () => {
    expect(validateField('name', 'abc')).toBeNull()
  })

  it('accepts a 100-character name', () => {
    expect(validateField('name', 'a'.repeat(100))).toBeNull()
  })

  it('rejects a 101-character name', () => {
    expect(validateField('name', 'a'.repeat(101))).toBe(
      'is too long (maximum is 100 characters)',
    )
  })
})

describe('validateField — description', () => {
  it('accepts an empty description (optional)', () => {
    expect(validateField('description', '')).toBeNull()
  })

  it('accepts a 1000-character description', () => {
    expect(validateField('description', 'a'.repeat(1000))).toBeNull()
  })

  it('rejects a 1001-character description', () => {
    expect(validateField('description', 'a'.repeat(1001))).toBe(
      'is too long (maximum is 1000 characters)',
    )
  })
})

describe('validateField — price', () => {
  it('rejects a blank price with the backend message', () => {
    expect(validateField('price', '')).toBe('is not a number')
  })

  it('rejects non-numeric input', () => {
    expect(validateField('price', 'abc')).toBe('is not a number')
  })

  it('rejects zero', () => {
    expect(validateField('price', '0')).toBe('must be greater than 0')
  })

  it('rejects a negative price', () => {
    expect(validateField('price', '-1')).toBe('must be greater than 0')
  })

  it('rejects three decimal places with the exact D-9 message', () => {
    expect(validateField('price', '9.999')).toBe(
      'must have at most 2 decimal places',
    )
  })

  it('accepts a valid two-decimal price', () => {
    expect(validateField('price', '49.99')).toBeNull()
  })
})

describe('validateField — stock', () => {
  it('rejects a blank stock', () => {
    expect(validateField('stock', '')).toBe('is not a number')
  })

  it('rejects a negative stock', () => {
    expect(validateField('stock', '-1')).toBe(
      'must be greater than or equal to 0',
    )
  })

  it('rejects a fractional stock', () => {
    expect(validateField('stock', '1.5')).toBe('must be an integer')
  })

  it('accepts zero', () => {
    expect(validateField('stock', '0')).toBeNull()
  })

  it('accepts a positive integer', () => {
    expect(validateField('stock', '12')).toBeNull()
  })
})

describe('validateField — sku', () => {
  it('rejects a missing sku', () => {
    expect(validateField('sku', '')).toBe("can't be blank")
  })

  it('rejects characters outside [A-Z0-9-]', () => {
    expect(validateField('sku', 'abc@123')).toBe('is invalid')
  })

  it('accepts a lowercase sku because it is uppercased first (D-6)', () => {
    expect(validateField('sku', 'abc-123')).toBeNull()
  })

  it('normalizes a lowercase sku to uppercase (D-6)', () => {
    expect(normalizeSku('abc-123')).toBe('ABC-123')
  })
})

describe('validateProduct', () => {
  it('returns no errors for a valid form', () => {
    expect(validateProduct(validForm())).toEqual({})
  })

  it('reports only the invalid fields, with the backend message', () => {
    const values = { ...validForm(), price: '9.999', stock: '1.5' }
    expect(validateProduct(values)).toEqual({
      price: 'must have at most 2 decimal places',
      stock: 'must be an integer',
    })
  })

  it('validates the sku case-insensitively via uppercasing', () => {
    expect(validateProduct({ ...validForm(), sku: 'abc-123' })).toEqual({})
  })
})
