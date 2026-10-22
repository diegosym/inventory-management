import { useEffect, useState } from 'react'

// Debounced search term (RF-2, ~300 ms): the returned value only follows
// `value` after `delayMs` have passed without a new input; the timer is
// cleaned up on every change and on unmount.
export function useDebouncedValue(value: string, delayMs = 300): string {
  const [debounced, setDebounced] = useState(value)

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs)
    return () => clearTimeout(timer)
  }, [value, delayMs])

  return debounced
}
