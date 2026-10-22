class ApplicationController < ActionController::API
  # Single error contract (RF-7, C10, plan D-P1): every error (404 / 422 / 500)
  # renders the same JSON shape via `render_error`; details only on 422.
  # Handlers are matched from the last registered to the first, so the generic
  # StandardError goes first and the specific handlers after it win.
  rescue_from StandardError, with: :render_internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failed

  private

  def render_error(status:, code:, message:, details: nil)
    error = { code: code, message: message }
    error[:details] = details if details
    render json: { error: error }, status: status
  end

  def render_not_found(_exception = nil)
    render_error(status: :not_found, code: 'not_found', message: 'Product not found')
  end

  # 422 comes only from the model's validations (C9): per-field details are the
  # Rails validation messages the frontend mirrors (NFR-3, C14).
  def render_validation_failed(exception)
    render_error(status: :unprocessable_entity, code: 'validation_failed',
                 message: 'Validation failed',
                 details: exception.record.errors.to_hash)
  end

  # Generic message only; the exception is logged server-side and its internals
  # never reach the response (plan error contract, RF-7).
  def render_internal_error(exception)
    logger.error("#{exception.class}: #{exception.message}")
    logger.error(exception.backtrace.first(10).join("\n")) if exception.backtrace
    render_error(status: :internal_server_error, code: 'internal_error',
                 message: 'Internal server error')
  end
end
