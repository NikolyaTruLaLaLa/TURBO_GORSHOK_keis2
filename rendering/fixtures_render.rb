# rendering/fixtures_render.rb
require 'json'
require_relative 'base_render'
require_relative '../ParsingOpenAPI/schema_extractor'

class FixturesRender < BaseRender
  def initialize(output_filename = 'fixtures.json')
    @output_filename = output_filename
  end

  def output_filename
    @output_filename
  end

  def render(data)
    @manifest = data
    fixtures = build_fixtures
    JSON.pretty_generate(fixtures)
  end

  private

  def build_fixtures
    {
      create_request: build_create_fixture,
      fetch_status: build_status_fixture,
      callback: build_callback_fixture(:completed),
      callback_failed: build_callback_fixture(:failed)
    }.compact
  end

  def build_create_fixture
    create_endpoint = find_endpoint_by_operation('createPayout')
    return nil unless create_endpoint

    schema = extract_request_schema(create_endpoint)
    return nil unless schema

    # Ищем пример из спецификации
    request_example = extract_example_from_schema(schema) || generate_example_from_schema(schema)

    # Извлекаем успешный и ошибочный ответы
    success_response = extract_response_example(create_endpoint, '201')
    error_response = extract_response_example(create_endpoint, '422') || extract_response_example(create_endpoint, '400')

    {
      request: request_example,
      response_201: success_response,
      response_422: error_response
    }.compact
  end

  def build_status_fixture
    status_endpoint = find_endpoint_by_operation('getPayoutStatus')
    return nil unless status_endpoint

    success_response = extract_response_example(status_endpoint, '200')
    return nil unless success_response

    { response_200: success_response }
  end

  def build_callback_fixture(event_type)
    webhook = @manifest.webhooks_map.values.first
    return nil unless webhook

    schema = extract_request_schema(webhook)
    return nil unless schema

    # Находим пример для конкретного события
    examples = extract_examples_from_schema(schema)
    example = examples.find { |ex| ex['event'] == (event_type == :completed ? 'payout.completed' : 'payout.failed') }
    return nil unless example

    {
      payload: example,
      expected_operation_status: event_type == :completed ? 'approved' : 'rejected'
    }
  end

  # Вспомогательные методы для извлечения примеров и генерации данных
  def find_endpoint_by_operation(operation_id)
    @manifest.endpoints_map.values.find { |e| e.operation.operation_id == operation_id }
  end

  def extract_request_schema(endpoint)
    SchemaExtractor.request_schema(endpoint.operation)
  end

  def extract_response_example(endpoint, status_code)
    response = endpoint.operation.responses[status_code]
    return nil unless response

    content = response.content
    return nil unless content

    json_content = content['application/json'] || content['application/json; charset=utf-8']
    return nil unless json_content

    example = json_content.example || json_content.examples&.values&.first&.value
    return example if example

    # Если примера нет – сгенерировать из схемы
    schema = json_content.schema
    return nil unless schema
    generate_example_from_schema(schema)
  end

  def extract_examples_from_schema(schema)
    # Ищем поле event и его enum
    properties = schema.properties || {}
    event_prop = properties['event']
    return [] unless event_prop && event_prop.enum

    # Для каждого значения enum пытаемся найти пример
    examples = []
    event_prop.enum.each do |event_value|
      example = {
        'event' => event_value,
        'payout_id' => 'np_7f3a9b2c',
        'external_id' => 'op_abc123',
        'status' => event_value.split('.').last
      }
      # Добавляем error для failed
      if event_value.include?('failed')
        example['error'] = { 'code' => 'recipient_not_found', 'message' => 'Recipient account not found' }
      end
      if event_value.include?('completed')
        example['completed_at'] = '2026-07-30T10:05:00Z'
      end
      examples << example
    end
    examples
  end

  def generate_example_from_schema(schema)
    # Базовая генерация данных на основе схемы
    example = {}
    properties = schema.properties || {}
    properties.each do |name, prop|
      example[name] = generate_value_for_property(prop)
    end
    example
  end

  def generate_value_for_property(prop)
    case prop.type
    when 'string'
      prop.example || 'example_string'
    when 'integer'
      prop.example || 1000
    when 'number'
      prop.example || 1.5
    when 'boolean'
      prop.example || false
    when 'object'
      generate_example_from_schema(prop)
    when 'array'
      [generate_value_for_property(prop.items)]
    else
      nil
    end
  end

  def extract_example_from_schema(schema)
    # Ищем явный пример
    return schema.example if schema.respond_to?(:example) && schema.example
    nil
  end
end