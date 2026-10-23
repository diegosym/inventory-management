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

# T4 (spec 005): anti-drift suite, live legs — RF-6(e) (live product shape),
# RF-6(f) (replay of every documented example, including the
# documented-as-implemented invalid-JSON 500 of RF-3), and the generic 500
# verified by simulation (D-P45, the 001 RF-16 precedent). Purely additive:
# T3's static examples and its `before(:context)` parse stay untouched.
#
# The replay iterates the DOCUMENT's examples (D-P48), so the document is
# parsed exactly once here — at load time, because RSpec registers examples
# at load time — and one example is registered per documented example (no
# example parses the YAML). Requests are derived from the document: the
# method and path from the operation; the `:id` from the path examples (the
# documented `"<existing-id>"` sentinel is substituted with the id of a
# fixture created through the documented POST `worked` example); the query
# value from the parameter examples; the body from the requestBody examples —
# a String body is sent raw, exactly as the document says. Every case creates
# its fixtures through the API inside the same example: hermetic,
# transactional, no factory, no seeds.
OPENAPI_DOC = YAML.safe_load(
  File.read(Rails.root.join('public', 'docs', 'openapi.yaml'))
)

# The documented replay sentinel (D-P48) and the path example carrying it —
# also the default `:id` when a response example names no path example.
SENTINEL_ID_EXAMPLE = 'existingId'
SENTINEL_ID_VALUE = '<existing-id>'.freeze

# Volatile values replayed by presence + type, never by value (D-P48).
REPLAY_VOLATILE_KEYS = %w[id created_at updated_at].freeze

# Request↔response examples pair by name (D-P48); these are the only
# cross-links, each stated by the examples' own summaries in the document.
REPLAY_CROSS_LINKS = {
  # PUT's 200 example is "the product after the `worked` request example".
  ['PUT', '/api/v1/products/{id}', 'existingId'] => { body: 'worked' },
  # DELETE's 404 example is "the `deletedProduct` path example deleted twice".
  ['DELETE', '/api/v1/products/{id}', 'repeatedDelete'] => { path: 'deletedProduct' }
}.freeze

# The generic 500 cannot be reproduced on demand: its documented examples
# are asserted against the simulated 500 below (D-P45), never replayed.
SIMULATED_500_EXAMPLE = 'genericError'.freeze

# The replay coverage the task requires (spec 005 tasks T4): one worked
# success per endpoint plus every documented error and empty family — a
# removed or renamed documented example turns the coverage example red.
required_replay_coverage = {
  ['GET', '/api/v1/products'] => %w[listing emptyNoMatch emptyOutOfRangePage
                                    malformedPage malformedQ malformedActive],
  ['POST', '/api/v1/products'] => %w[worked invalidBody missingWrapper invalidJson],
  ['GET', '/api/v1/products/{id}'] => %w[existingId unknownId nonNumericId deletedProduct],
  ['PUT', '/api/v1/products/{id}'] => %w[existingId unknownId nonNumericId deletedProduct
                                         omittedRequiredField nullActive invalidJson],
  ['DELETE', '/api/v1/products/{id}'] => %w[existingId unknownId nonNumericId
                                            repeatedDelete]
}.freeze

# One replay case per documented example, derived from the document at load
# time: :status and :expected from the documented response; :id, :query, and
# :body from the documented request examples (D-P48).
def replay_case_for(method, path, name, status, expected, path_examples,
                    query_examples, body_examples)
  link = REPLAY_CROSS_LINKS[[method.upcase, path, name]] || {}
  id = nil
  setup = nil
  if path.include?('{id}')
    # Fails loudly at load if the document drops the sentinel example.
    id_example = link[:path] || (path_examples.key?(name) ? name : SENTINEL_ID_EXAMPLE)
    id = path_examples.fetch(id_example)
    setup = :soft_delete if id_example == 'deletedProduct' # "DELETE it first"
  end
  { method: method.upcase, path: path, name: name, status: status.to_i,
    expected: expected, id: id, setup: setup, query: query_examples[name],
    body: link[:body] ? body_examples.fetch(link[:body]) : body_examples[name],
    fixture: method != 'post' }
end

replay_cases = []
OPENAPI_DOC.fetch('paths').each do |path, item|
  %w[get post put delete].each do |method|
    operation = item[method]
    next unless operation

    query_examples = {}
    path_examples = {}
    ((item['parameters'] || []) + (operation['parameters'] || [])).each do |parameter|
      (parameter['examples'] || {}).each do |name, example|
        case parameter['in']
        when 'query' then query_examples[name] = [parameter['name'], example['value']]
        when 'path' then path_examples[name] = example['value']
        end
      end
    end

    request_json = operation.dig('requestBody', 'content', 'application/json') || {}
    body_examples = (request_json['examples'] || {}).transform_values do |example|
      example.is_a?(Hash) && example.key?('value') ? example['value'] : example
    end

    operation.fetch('responses').each do |status, response|
      if response.key?('content')
        (response.dig('content', 'application/json', 'examples') || {}).each do |name, example|
          next if name == SIMULATED_500_EXAMPLE # asserted by simulation (D-P45)
          expected = example.is_a?(Hash) && example.key?('value') ? example['value'] : example
          replay_cases << replay_case_for(method, path, name, status, expected,
                                          path_examples, query_examples, body_examples)
        end
      else
        # A content-less success (204): the document pairs it with the
        # `existingId` path example — "any existing, non-deleted product id".
        replay_cases << replay_case_for(method, path, SENTINEL_ID_EXAMPLE, status, nil,
                                        path_examples, query_examples, body_examples)
      end
    end
  end
end

RSpec.describe 'OpenAPI anti-drift — live legs (spec 005 RF-6)' do
  # --- helpers --------------------------------------------------------------

  # The replay's only fixture: a product created through the document's
  # `worked` POST example, inside the example that needs it.
  def create_documented_fixture
    worked = OPENAPI_DOC.dig('paths', '/api/v1/products', 'post', 'requestBody',
                             'content', 'application/json', 'examples', 'worked', 'value')
    post '/api/v1/products', params: worked, as: :json
    expect(response).to have_http_status(:created),
                        "the documented POST worked example must create the fixture: #{response.body}"
    JSON.parse(response.body).fetch('data').fetch('id')
  end

  # Executes one replay case exactly as the document writes it (D-P48).
  def replay!(replay_case)
    fixture_id = create_documented_fixture if replay_case[:fixture]
    if replay_case[:setup] == :soft_delete
      # The documented `deletedProduct` example: "(DELETE it first)".
      delete "/api/v1/products/#{fixture_id}"
      expect(response).to have_http_status(:no_content),
                          'the fixture soft-delete setup must answer 204'
    end

    path = replay_case[:path]
    if path.include?('{id}')
      id = replay_case[:id] == SENTINEL_ID_VALUE ? fixture_id.to_s : replay_case[:id]
      path = path.sub('{id}', id)
    end

    http_method = replay_case[:method].downcase
    body = replay_case[:body]
    if body.is_a?(String)
      # Documented raw body: sent exactly as shown, not JSON-encoded.
      send(http_method, path, params: body,
                              headers: { 'CONTENT_TYPE' => 'application/json' })
    elsif body
      send(http_method, path, params: body, as: :json)
    elsif replay_case[:query]
      name, value = replay_case[:query]
      send(http_method, path, params: { name => value })
    else
      send(http_method, path)
    end
  end

  # Deep compare of the live body against the documented example:
  # deterministic values exactly; volatile ones (`id`, timestamps) by
  # presence + type (D-P48).
  def expect_documented_body!(live, expected, context)
    case expected
    when Hash
      expect(live).to be_a(Hash), "#{context}: expected a JSON object"
      expect(live.keys).to match_array(expected.keys), "#{context}: documented keys"
      expected.each do |key, expected_value|
        if REPLAY_VOLATILE_KEYS.include?(key)
          expect(live[key]).not_to be_nil, "#{context}: documented key #{key} missing"
          expect(live[key].class).to eq(expected_value.class), "#{context}: #{key} type"
        else
          expect_documented_body!(live[key], expected_value, "#{context}.#{key}")
        end
      end
    when Array
      expect(live).to be_a(Array), "#{context}: expected a JSON array"
      expect(live.size).to eq(expected.size), "#{context}: array size"
      expected.each_with_index do |value, index|
        expect_documented_body!(live[index], value, "#{context}[#{index}]")
      end
    else
      expect(live).to eq(expected),
                      "#{context}: expected #{expected.inspect}, got #{live.inspect}"
    end
  end

  # Every documented 500 example body, keyed by where it lives in the document.
  def documented_500_examples
    examples = {}
    OPENAPI_DOC.fetch('paths').each do |path, item|
      %w[get post put delete].each do |method|
        response_500 = item.dig(method, 'responses', '500')
        next unless response_500

        content = response_500.dig('content', 'application/json')
        next unless content

        location = "#{method.upcase} #{path}"
        (content['examples'] || {}).each do |name, example|
          examples["#{location} examples.#{name}"] =
            example.is_a?(Hash) && example.key?('value') ? example['value'] : example
        end
        examples["#{location} example"] = content['example'] if content.key?('example')
      end
    end
    examples
  end

  # --- RF-6(e) -------------------------------------------------------------

  describe 'RF-6(e): a live product matches the documented Product schema' do
    it 'answers a real GET with exactly the documented properties and a 2-decimal price' do
      fixture_id = create_documented_fixture

      get "/api/v1/products/#{fixture_id}"

      expect(response).to have_http_status(:ok)
      product = JSON.parse(response.body).fetch('data')
      properties = OPENAPI_DOC.dig('components', 'schemas', 'Product', 'properties')
      expect(product.keys).to match_array(properties.keys)
      expect(product.fetch('price'))
        .to match(Regexp.new(properties.fetch('price').fetch('pattern')))
    end
  end

  # --- RF-6(f) -------------------------------------------------------------

  describe 'RF-6(f): the documented examples replay against the live API' do
    it 'covers the required example set (one worked success per endpoint, every documented error and empty family)' do
      coverage = replay_cases
                   .group_by { |replay_case| [replay_case[:method], replay_case[:path]] }
                   .transform_values { |cases| cases.map { |replay_case| replay_case[:name] } }
      expect(coverage.transform_values(&:sort))
        .to eq(required_replay_coverage.transform_values(&:sort))
    end

    replay_cases.each do |replay_case|
      it "#{replay_case[:method]} #{replay_case[:path]} example #{replay_case[:name]} answers the documented #{replay_case[:status]}" do
        replay!(replay_case)

        expect(response).to have_http_status(replay_case[:status])
        if replay_case[:expected].nil?
          expect(response.body).to be_empty
        else
          expect_documented_body!(JSON.parse(response.body), replay_case[:expected],
                                  "#{replay_case[:method]} #{replay_case[:path]} #{replay_case[:name]}")
        end
      end
    end

    it 'leaves the deleted product out of the listings (documented DELETE semantics)' do
      fixture_id = create_documented_fixture

      delete "/api/v1/products/#{fixture_id}"
      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty

      get '/api/v1/products'
      body = JSON.parse(response.body)
      expect(body.fetch('data').map { |product| product.fetch('id') })
        .not_to include(fixture_id)
      expect(body.fetch('meta'))
        .to eq('current_page' => 1, 'total_count' => 0, 'total_pages' => 0)
    end
  end

  # --- the generic 500 (D-P45, the 001 RF-16 precedent) --------------------

  describe 'RF-6(f): the generic 500 example, verified by simulation (D-P45)' do
    it 'matches every documented 500 example when a model call raises' do
      documented_examples = documented_500_examples
      expect(documented_examples).not_to be_empty

      allow(Product).to receive(:find_by!).and_raise('simulated unexpected failure')

      get '/api/v1/products/1'

      expect(response).to have_http_status(:internal_server_error)
      live = JSON.parse(response.body)
      documented_examples.each do |location, example|
        expect(live).to eq(example),
                        "#{location}: the simulated live 500 must equal the documented example"
      end
    end
  end
end
