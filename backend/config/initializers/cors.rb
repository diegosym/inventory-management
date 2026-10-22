# Be sure to restart your server when you modify this file.

# CORS (RF-8, spec 001 / D-7): allow the frontend dev-server origin configured
# via FRONTEND_ORIGIN (.env — C16: the allowlist lives in the environment, never
# in the repo). Methods and headers are the minimal set the frontend needs.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173")

    resource "/api/v1/*",
      headers: :any,
      methods: [:get, :post, :put, :delete, :options]
  end
end
