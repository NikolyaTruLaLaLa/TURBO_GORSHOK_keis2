# Rendering/service_render.rb
require_relative 'base_render'
require_relative 'method_driver/create_request_method_driver'
require_relative '../ParsingOpenAPI/schema_extractor'

class ServiceRender < BaseRender
  def initialize(output_filename = 'service.rb')
    @output_filename = output_filename
    @method_drivers = [
      CreateRequestMethodDriver.new,
      # другие драйверы позже
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
    @manifest.webhooks_map.each do |name, endpoint|
      schema = SchemaExtractor.request_schema(endpoint.operation)
      next unless schema

      event_field = find_event_field(schema)
      next unless event_field && event_field.respond_to?(:enum) && event_field.enum

      event_field.enum.each do |event_value|
        internal = map_event_to_status(event_value)
        mapping << [event_value, internal] if internal
      end
    end
    mapping.uniq
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
    # TODO: из эвристики
    {}
  end
end