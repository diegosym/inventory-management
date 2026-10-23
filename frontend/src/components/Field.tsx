import type { ChangeEvent } from 'react'

interface FieldProps {
  id: string
  label: string
  value: string
  /** Messages under the control ([] when valid); RF-8 renders every 422 detail. */
  errors: string[]
  onChange: (value: string) => void
  inputMode?: 'decimal'
  placeholder?: string
  multiline?: boolean
}

// Label + control + errors with RF-12's a11y wiring: a htmlFor/id pair, the
// aria-invalid flag while invalid, and every message associated through one
// aria-describedby container (RF-8 renders the whole 422 array under the field).
export function Field({
  id,
  label,
  value,
  errors,
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
    errors.length === 0 ? {} : { 'aria-invalid': true, 'aria-describedby': errorId }

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
      {errors.length === 0 ? null : (
        <div id={errorId} className="space-y-1">
          {errors.map((message) => (
            <p key={message} className="text-sm text-danger">
              {message}
            </p>
          ))}
        </div>
      )}
    </div>
  )
}
