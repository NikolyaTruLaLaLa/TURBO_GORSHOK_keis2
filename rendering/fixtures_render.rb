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
    if fixtures.empty?
      # Если не удалось сгенерировать фикстуры, возвращаем пустой объект с комментарием
      return {}.to_json
    end
    JSON.pretty_generate(fixtures)
  end

  private

  def build_fixtures
    {
      create_request: build_create_fixture,
      fetch_status: build_status_fixture,
      callback: build_callback_fixture('payout.completed'),
      callback_failed: build_callback_fixture('payout.failed')
    }.compact
  end

  def build_create_fixture
    # Ищем эндпоинты для создания платежа (deposit) и выплаты (payout)
    deposit_endpoint = find_endpoint_by_operation('createPayment') || find_endpoint_by_path('/payments', 'post')
    payout_endpoint = find_endpoint_by_operation('createPayout') || find_endpoint_by_path('/payouts', 'post')

    # Для ЮKassa создаём пример для депозита (платежа)
    endpoint = deposit_endpoint
    return nil unless endpoint

    schema = extract_request_schema(endpoint)
    return nil unless schema

    # Генерируем пример запроса на основе схемы
    request_example = generate_example_from_schema(schema)
    # Добавляем недостающие поля, если они обязательны (например, для ЮKassa)
    request_example = enrich_payment_request(request_example)

    # Извлекаем успешный и ошибочный ответы
    success_response = extract_response_example(endpoint, '200') || extract_response_example(endpoint, '201')
    error_response = extract_response_example(endpoint, '400') || extract_response_example(endpoint, '422')

    {
      request: request_example,
      response_200: success_response,
      response_400: error_response
    }.compact
  end

  def build_status_fixture
    status_endpoint = find_endpoint_by_operation('getPaymentStatus') ||
                      find_endpoint_by_path('/payments/{payment_id}', 'get') ||
                      find_endpoint_by_path('/payouts/{payout_id}', 'get')
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

    # Генерируем пример на основе схемы, подставляя нужное событие
    example = generate_example_from_schema(schema)
    example['event'] = event_type
    example['status'] = event_type.split('.').last

    # Для ЮKassa добавление типовых полей
    example['payout_id'] = 'np_7f3a9b2c' unless example['payout_id']
    example['external_id'] = 'op_abc123' unless example['external_id']

    expected_status = case event_type
                      when /completed|succeeded/
                        'approved'
                      when /failed|rejected|cancelled/
                        'rejected'
                      else
                        'in_progress'
                      end

    {
      payload: example,
      expected_operation_status: expected_status
    }
  end

  # Вспомогательные методы

  def find_endpoint_by_path(path, method)
    @manifest.endpoints_map.values.find { |e| e.path == path && e.http_method.to_s == method }
  end

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

    # Сначала пытаемся взять явный пример
    example = json_content.example || json_content.examples&.values&.first&.value
    return example if example

    # Если примера нет – генерируем на основе схемы
    schema = json_content.schema
    return nil unless schema
    generate_example_from_schema(schema)
  end

  def generate_example_from_schema(schema, path = '')
    # Обработка ссылок
    if schema.respond_to?(:resolve)
      schema = schema.resolve
    end

    return nil unless schema

    # Если схема имеет enum – берём первое значение
    if schema.respond_to?(:enum) && schema.enum && !schema.enum.empty?
      return schema.enum.first
    end

    # Если схема – объект
    if schema.respond_to?(:properties)
      example = {}
      properties = schema.properties || {}
      required = schema.required || []

      # Генерируем значения для всех полей
      properties.each do |name, prop|
        # Для обязательных полей генерируем всегда, для опциональных – добавляем, если это простые типы
        if required.include?(name)
          example[name] = generate_value_for_property(prop, path + ".#{name}")
        else
          # Для опциональных добавляем только если это не сложный объект
          if prop.type == 'object' || prop.type == 'array'
            # Не добавляем пустые объекты/массивы
          else
            example[name] = generate_value_for_property(prop, path + ".#{name}")
          end
        end
      end
      return example
    end

    # Если схема – массив
    if schema.type == 'array'
      item_schema = schema.items
      return [] unless item_schema
      # Генерируем один элемент массива
      [generate_value_for_property(item_schema, path + '[]')]
    end

    # Если схема – anyOf / oneOf / allOf
    %i[any_of one_of all_of].each do |key|
      next unless schema.respond_to?(key)
      schemas = schema.public_send(key)
      next unless schemas && !schemas.empty?
      # Берём первую подходящую схему
      sub_schema = schemas.first
      return generate_example_from_schema(sub_schema, path)
    end

    # Если схема – простая (string, integer, etc)
    generate_simple_value(schema)
  end

  def generate_value_for_property(prop, path)
    # Если есть пример – берём его
    if prop.respond_to?(:example) && prop.example
      return prop.example
    end

    # Если есть enum – берём первое
    if prop.respond_to?(:enum) && prop.enum && !prop.enum.empty?
      return prop.enum.first
    end

    case prop.type
    when 'object'
      generate_example_from_schema(prop, path)
    when 'array'
      item_schema = prop.items
      return [] unless item_schema
      [generate_value_for_property(item_schema, path + '[]')]
    else
      generate_simple_value(prop)
    end
  end

  def generate_simple_value(prop)
    case prop.type
    when 'string'
      prop.example || 'example_string'
    when 'integer'
      prop.example || 1000
    when 'number'
      prop.example || 1.5
    when 'boolean'
      prop.example || false
    else
      nil
    end
  end

  # Специальное обогащение для запроса платежа ЮKassa
  def enrich_payment_request(example)
    # Если нет обязательных полей – добавляем
    example['amount'] ||= { 'value' => '100.00', 'currency' => 'RUB' }
    example['payment_method_data'] ||= { 'type' => 'bank_card' }
    example['confirmation'] ||= { 'type' => 'redirect', 'return_url' => 'https://example.com/return' }
    example['description'] ||= 'Test payment'
    example
  end
end