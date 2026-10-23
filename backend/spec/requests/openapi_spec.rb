require 'rails_helper'

# T3 (spec 005): anti-drift suite, static legs — RF-6(a)…(d), (g); RF-5's
# static legs (no-CDN + availability); RF-7 (ordinary suite, no CI change).
# The committed document is parsed exactly once (D-P43: Ruby stdlib
# `YAML.safe_load`, no gem) and asserted against the implemented API, which
# remains the source of truth: a code change that breaks the document turns
# this spec red until the document is updated in the same change. The live
# legs — (e) product shape, (f) example replay, and the simulated 500 — land
# with T4 in this same file.
#
# The contract encoded here (specs 001 + 004): the five product endpoints and
# their parameters, success statuses, and error statuses exactly as the
# controllers implement them. The documentation URLs are served statically
# from public/ (D-P41), so they are asserted as served URLs, not as routes.

# The five documented product endpoints (spec 001 RF-1; the document records
# PUT for update per RF-1 — `resources` draws PATCH too, reconciled below
# against the route table).
documented_operations = [
  ['GET', '/api/v1/products'],
  ['POST', '/api/v1/products'],
  ['GET', '/api/v1/products/{id}'],
  ['PUT', '/api/v1/products/{id}'],
  ['DELETE', '/api/v1/products/{id}']
].freeze

# Implemented parameters per operation (001 RF-9…RF-13, C11): `page`, `q`,
# and `active` on the listing; the path `:id` on show/update/destroy; none on
# create. None invented, none missing.
expected_parameters = {
  ['GET', '/api/v1/products'] => { 'page' => 'query', 'q' => 'query',
                                   'active' => 'query' },
  ['POST', '/api/v1/products'] => {},
  ['GET', '/api/v1/products/{id}'] => { 'id' => 'path' },
  ['PUT', '/api/v1/products/{id}'] => { 'id' => 'path' },
  ['DELETE', '/api/v1/products/{id}'] => { 'id' => 'path' }
}.freeze

# Implemented success statuses (001 RF-1): 200 list/show/update, 201 create,
# 204 with an empty body on delete.
expected_success_statuses = {
  ['GET', '/api/v1/products'] => ['200'],
  ['POST', '/api/v1/products'] => ['201'],
  ['GET', '/api/v1/products/{id}'] => ['200'],
  ['PUT', '/api/v1/products/{id}'] => ['200'],
  ['DELETE', '/api/v1/products/{id}'] => ['204']
}.freeze

# Implemented error statuses (C10, specs 001 + 004): the listing never 404s
# (empty results answer 200); show/update/destroy 404 on unknown, non-numeric,
# and soft-deleted ids (repeated DELETE included); body and listing-parameter
# validation answer 422; every endpoint keeps the generic 500.
expected_error_statuses = {
  ['GET', '/api/v1/products'] => %w[422 500],
  ['POST', '/api/v1/products'] => %w[422 500],
  ['GET', '/api/v1/products/{id}'] => %w[404 500],
  ['PUT', '/api/v1/products/{id}'] => %w[404 422 500],
  ['DELETE', '/api/v1/products/{id}'] => %w[404 500]
}.freeze

vendored_assets = %w[
  /docs/swagger-ui/swagger-ui.css
  /docs/swagger-ui/swagger-ui-bundle.js
  /docs/swagger-ui/swagger-ui-standalone-preset.js
].freeze

RSpec.describe 'OpenAPI anti-drift — static legs (spec 005 RF-6)' do
  # Parse the committed document exactly once for the whole file (D-P43).
  before(:context) do
    @doc = YAML.safe_load(
      File.read(Rails.root.join('public', 'docs', 'openapi.yaml'))
    )
  end

  # --- helpers (operate on the once-parsed document) -----------------------

  HTTP_METHODS = %w[get put post delete options head patch trace].freeze
  ERROR_SCHEMA_REF = { '$ref' => '#/components/schemas/Error' }.freeze

  # The documented operations as [METHOD, path] pairs.
  def doc_operations
    @doc.fetch('paths').flat_map do |path, item|
      HTTP_METHODS.select { |m| item.key?(m) }.map { |m| [m.upcase, path] }
    end
  end

  def operation_for(method, path)
    item = @doc.fetch('paths').fetch(path)
    [item, item.fetch(method.downcase)]
  end

  # Effective parameters of an operation: path-level (e.g. the `{id}` sentinel)
  # plus operation-level entries, as [name, location] pairs.
  def documented_parameters(method, path)
    item, operation = operation_for(method, path)
    ((item['parameters'] || []) + (operation['parameters'] || []))
      .map { |parameter| [parameter.fetch('name'), parameter.fetch('in')] }
  end

  def documented_statuses(method, path)
    operation_for(method, path).last.fetch('responses').keys
  end

  def each_error_response
    doc_operations.each do |method, path|
      operation_for(method, path).last.fetch('responses').each do |status, response|
        yield(method, path, status, response) if status.match?(/\A[45]\d\d\z/)
      end
    end
  end

  # The application's route entries with the Rails internals filtered out
  # (D-P44: `/rails/*` and `/cable`), normalized to [METHOD, path] pairs with
  # the format suffix dropped and `:id` in the document's `{id}` form.
  def app_route_entries
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      next if path.start_with?('/rails/') || path == '/cable'
      [route.verb.to_s, path.sub(/\(\.:format\)\z/, '').gsub(':id', '{id}')]
    end
  end

  describe 'RF-6(a): documented operations equal the served route surface' do
    it 'documents exactly the five product endpoints — none invented, none missing' do
      expect(doc_operations.sort).to eq(documented_operations.sort)
    end

    it 'serves exactly those endpoints plus the PATCH twin of update — no more, no less (D-P44)' do
      patch_twins = documented_operations
                      .select { |method, _| method == 'PUT' }
                      .map { |_, path| ['PATCH', path] }
      expect(app_route_entries.sort)
        .to eq((documented_operations + patch_twins).sort)
    end

    it 'serves the document at GET /docs/openapi.yaml and the UI at GET /docs (served URLs, not routes — D-P41)' do
      get '/docs/openapi.yaml'
      expect(response).to have_http_status(:ok)

      get '/docs'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'RF-6(b): documented parameters equal the implemented ones' do
    expected_parameters.each do |(method, path), expected|
      it "#{method} #{path} documents exactly #{expected.keys.inspect}" do
        expect(documented_parameters(method, path).sort)
          .to eq(expected.map { |name, location| [name, location] }.sort)
      end
    end
  end

  describe 'RF-6(c): documented success statuses equal the implemented ones' do
    expected_success_statuses.each do |(method, path), expected|
      it "#{method} #{path} documents exactly #{expected.join(', ')}" do
        statuses = documented_statuses(method, path).grep(/\A2\d\d\z/)
        expect(statuses.sort).to eq(expected.sort)
      end
    end

    it 'documents DELETE as 204 with an empty body' do
      response_204 = operation_for('DELETE', '/api/v1/products/{id}')
                        .last.fetch('responses').fetch('204')
      expect(response_204).not_to have_key('content')
    end
  end

  describe 'RF-6(d): the documented error contract matches the implemented one' do
    it 'references the shared Error schema from every documented 4xx/5xx response' do
      each_error_response do |method, path, status, response|
        schema = response.dig('content', 'application/json', 'schema')
        expect(schema).to eq(ERROR_SCHEMA_REF),
                          "#{method} #{path} #{status} must use the shared Error schema"
      end
    end

    it "defines the Error schema's code enum as exactly {not_found, validation_failed, internal_error}" do
      code = @doc.dig('components', 'schemas', 'Error', 'properties', 'error',
                      'properties', 'code')
      expect(code.fetch('enum').sort)
        .to eq(%w[internal_error not_found validation_failed])
    end

    it 'keeps details out of the shared schema required keys (only 422 carries it)' do
      error = @doc.dig('components', 'schemas', 'Error', 'properties', 'error')
      expect(error.fetch('required')).to match_array(%w[code message])
    end

    expected_error_statuses.each do |(method, path), expected|
      it "#{method} #{path} documents exactly #{expected.join(', ')}" do
        statuses = documented_statuses(method, path).grep(/\A[45]\d\d\z/)
        expect(statuses.sort).to eq(expected.sort)
      end
    end

    it 'gives every error example the code its status implements, with details only on 422' do
      code_by_status = { '404' => 'not_found', '422' => 'validation_failed',
                         '500' => 'internal_error' }
      each_error_response do |method, path, status, response|
        content = response.fetch('content').fetch('application/json')
        # Named examples are `{summary, value}` objects — the body lives under
        # `value`; the singular `example` shortcut holds the bare body.
        examples = (content['examples'] || {}).values.map do |example|
          example.is_a?(Hash) && example.key?('value') ? example['value'] : example
        end
        examples << content['example'] if content.key?('example')
        expect(examples).not_to be_empty,
                                 "#{method} #{path} #{status} must carry an example"

        examples.each do |example|
          error = example.fetch('error')
          context = "#{method} #{path} #{status} example"
          expect(error.fetch('code')).to eq(code_by_status.fetch(status)), context
          if status == '422'
            expect(error).to have_key('details'), context
          else
            expect(error).not_to have_key('details'), context
          end
        end
      end
    end
  end

  describe 'RF-6(g): the served document is byte-identical to the committed file' do
    it 'answers GET /docs/openapi.yaml with the committed file bytes' do
      get '/docs/openapi.yaml'

      expect(response).to have_http_status(:ok)
      expect(response.body.b)
        .to eq(File.binread(Rails.root.join('public', 'docs', 'openapi.yaml')))
    end
  end

  describe 'RF-5 (static legs): the docs UI is available and self-contained' do
    it 'serves GET /docs as HTML with no external http(s) reference (no CDN)' do
      get '/docs'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(response.body).not_to match(%r{https?://})
    end

    vendored_assets.each do |asset_url|
      it "serves the vendored asset #{asset_url}" do
        get asset_url

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
