import type { ChangeEvent } from 'react'

interface FieldProps {
  id: string
  label: string
  value: string
  /** Mirror message under the control, or null when the field is valid. */
  error: string | null
  onChange: (value: string) => void
  inputMode?: 'decimal'
  placeholder?: string
  multiline?: boolean
}

// Label + control + error with RF-12's a11y wiring: a htmlFor/id pair, the
// aria-invalid flag while invalid, and the message associated through
// aria-describedby.
export function Field({
  id,
  label,
  value,
  error,
  onChange,
  inputMode,
  placeholder,
  multiline = false,
}: FieldProps) {
  const errorId = `${id}-error`
  const className = 'w-full rounded-md border border-gray-300 px-3 py-2'

  function handleInput(
    event: ChangeEvent<HTMLInputElement> | ChangeEvent<HTMLTextAreaElement>,
  ): void {
    onChange(event.target.value)
  }

  const errorAttributes =
    error === null ? {} : { 'aria-invalid': true, 'aria-describedby': errorId }

  return (
    <div className="space-y-1">
      <label htmlFor={id} className="block text-sm font-medium text-gray-700">
        {label}
      </label>
      {multiline ? (
        <textarea
          id={id}
          rows={4}
          value={value}
          placeholder={placeholder}
          onChange={handleInput}
          {...errorAttributes}
          className={className}
        />
      ) : (
        <input
          id={id}
          type="text"
          inputMode={inputMode}
          value={value}
          placeholder={placeholder}
          onChange={handleInput}
          {...errorAttributes}
          className={className}
        />
      )}
      {error === null ? null : (
        <p id={errorId} className="text-sm text-danger">
          {error}
        </p>
      )}
    </div>
  )
}
