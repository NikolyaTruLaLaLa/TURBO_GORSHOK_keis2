# Rendering/service_render.rb
require_relative 'base_render'
require_relative 'method_driver/create_request_method_driver'
require_relative 'method_driver/fetch_status_method_driver'
require_relative 'method_driver/process_callback_method_driver'
require_relative 'method_driver/check_conditions_method_driver'
require_relative 'method_driver/webhook_signing_method_driver'
require_relative 'method_driver/digital_signing_method_driver'
require_relative 'method_driver/data_encryption_method_driver'
require_relative '../ParsingOpenAPI/schema_extractor'

class ServiceRender < BaseRender
  def initialize(output_filename = 'service.rb')
    @output_filename = output_filename
    @method_drivers = [
      CreateRequestMethodDriver.new,
      FetchStatusMethodDriver.new,
      ProcessCallbackMethodDriver.new,
      CheckConditionsMethodDriver.new,
      WebhookSigningMethodDriver.new,
      DigitalSigningMethodDriver.new,
      DataEncryptionMethodDriver.new,
    ]
  end

  def output_filename
    @output_filename
  end

  def render(data)
    @manifest = data
    methods_code = @method_drivers.map { |driver| driver.generate(@manifest) }.join("\n\n")

    provider_name = @manifest.provider_name
    provider_class_name = provider_name.split('_').map(&:capitalize).join
    default_base_url = extract_default_base_url
    status_mapping = extract_status_mapping
    error_mapping = extract_error_mapping

    template_path = File.join(__dir__, 'templates', 'new_service.rb.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result_with_hash(
      provider_name: provider_name,
      provider_class_name: provider_class_name,
      default_base_url: default_base_url,
      status_mapping: status_mapping,
      error_mapping: error_mapping,
      methods_code: methods_code
    )
  end

  private

  def extract_default_base_url
    @manifest.servers['Production'] || @manifest.servers.values.first || ''
  end

  def extract_status_mapping
    mapping = []
    # Ищем эндпоинт статуса (для payment или payout)
    status_endpoint = find_status_endpoint_for_mapping
    return mapping unless status_endpoint

    schema = SchemaExtractor.response_schema(status_endpoint.operation, '200')
    return mapping unless schema

    status_field = find_status_field(schema)
    return mapping unless status_field && status_field.respond_to?(:enum)

    status_field.enum.each do |status_value|
      internal = map_status_value(status_value)
      mapping << [status_value, internal] if internal
    end
    mapping.uniq
  end

  def find_status_endpoint_for_mapping
    @manifest.endpoints_map.values.find do |e|
      e.http_method == :get && e.path.include?('{') &&
      (e.path.include?('payment') || e.path.include?('payout'))
    end
  end

  def find_status_field(schema)
    properties = schema.properties
    return nil unless properties

    return properties['status'] if properties['status']
    return properties['state'] if properties['state']
    nil
  end

  def map_status_value(status)
    case status.downcase
    when 'pending', 'waiting_for_capture', 'processing'
      'in_progress'
    when 'succeeded', 'completed'
      'approved'
    when 'canceled', 'failed', 'rejected'
      'rejected'
    else
      nil
    end
  end

  def find_event_field(schema)
    properties = schema.properties
    return nil unless properties

    # Проверяем наличие ключей через прямой доступ
    return properties['event'] if properties['event']
    return properties['type'] if properties['type']

    nil
  end

  def map_event_to_status(event)
    case event.downcase
    when /completed|succeeded|approved/
      'approved'
    when /failed|error|declined|rejected|cancelled/
      'rejected'
    when /pending|processing|in_progress/
      'in_progress'
    else
      nil
    end
  end

  def extract_error_mapping
    default_codes = {
      '400' => 'validation_error',
      '401' => 'unauthorized',
      '402' => 'insufficient_balance',
      '403' => 'forbidden',
      '404' => 'not_found',
      '422' => 'validation_error',
      '429' => 'rate_limit',
      '500' => 'internal_error',
      '502' => 'internal_error',
      '503' => 'internal_error',
      '504' => 'internal_error'
    }

    operations = collect_all_operations
    mapping = {}

    operations.each do |operation|
      next unless operation.respond_to?(:responses)

      operation.responses.each do |status, _response|
        status_str = status.to_s
        next unless status_str.match?(/^[45]\d\d$/)

        internal = default_codes[status_str] || 'internal_error'
        mapping[status_str] = internal
      end
    end

    mapping = default_codes.dup if mapping.empty?
    mapping
  end

  def collect_all_operations
    ops = []
    return ops unless @manifest.respond_to?(:endpoints_map)

    @manifest.endpoints_map.each do |_name, endpoint|
      operation = endpoint.respond_to?(:operation) ? endpoint.operation : endpoint
      next unless operation

      ops << operation
    end
    ops
  end
end
