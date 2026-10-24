# Production image (spec 006, D-P49): one multi-stage build for the whole
# deployed application — the Vite production build (stage 1) shipped inside
# the Rails API image (stage 2). Dev compose keeps its own Dockerfiles (NFR-1).

# stage 1 — the production frontend build (RF-1)
FROM node:22 AS frontend
WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
# D-P53/RF-3: the API base URL is baked at build time from the provider's
# environment; an omitted value must fail the build loudly instead of
# shipping a bundle that calls `undefined`.
ARG VITE_API_BASE_URL
RUN test -n "$VITE_API_BASE_URL" || { echo "VITE_API_BASE_URL build arg is required (spec 006 RF-3)" >&2; exit 1; }
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build # tsc -b + vite build — the exact CI/local build

# stage 2 — the API + the built frontend (RF-1, RF-7)
FROM ruby:3.3
# libpq is required to build the pg gem.
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends libpq-dev \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY backend/Gemfile backend/Gemfile.lock ./
RUN bundle install
COPY backend/ .
# index.html at /, assets at /assets/* — served by Rails' static middleware
# (enabled by default in production); backend/public/docs/ ships untouched.
COPY --from=frontend /app/dist ./public/
EXPOSE 3000
# Boot chain (D-P52): provision/migrate + idempotent re-seed on every start,
# then exec puma so it receives container signals (graceful shutdown).
CMD ["sh", "-c", "bin/rails db:prepare db:seed && exec bundle exec puma -C config/puma.rb"]
