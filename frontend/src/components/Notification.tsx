export interface Notice {
  kind: 'success' | 'error'
  message: string
}

interface NotificationProps {
  notice: Notice
  onDismiss: () => void
}

// In-page feedback (C15): persistent until dismissed or replaced — no timers,
// so the message never vanishes while the user reads it. Success uses the
// polite role="status"; errors use the assertive role="alert".
export function Notification({ notice, onDismiss }: NotificationProps) {
  return (
    <div
      role={notice.kind === 'success' ? 'status' : 'alert'}
      className="fixed right-4 top-4 z-20 flex w-80 items-start gap-3 rounded-md bg-white p-4 shadow-lg"
    >
      <p
        className={`flex-1 text-sm ${notice.kind === 'success' ? 'text-brand' : 'text-danger'}`}
      >
        {notice.message}
      </p>
      <button
        type="button"
        aria-label="Dismiss"
        onClick={onDismiss}
        className="text-sm font-medium text-gray-500"
      >
        ×
      </button>
    </div>
  )
}
