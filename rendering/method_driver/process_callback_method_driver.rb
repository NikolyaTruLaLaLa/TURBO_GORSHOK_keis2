require_relative 'method_driver'
require_relative '../../ParsingOpenAPI/schema_extractor'
require 'erb'

class ProcessCallbackMethodDriver < MethodDriver
  def generate(manifest)
    webhook_endpoint = find_webhook_endpoint(manifest.webhooks_map)
    return '' unless webhook_endpoint

    # Извлекаем схему запроса вебхука
    schema = SchemaExtractor.request_schema(webhook_endpoint.operation)
    events = extract_events(schema)

    template_path = File.join(__dir__, '../templates/methods/_process_callback.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result(binding)
  end

  private

  def find_webhook_endpoint(webhooks_map)
    webhooks_map.values.first
  end

  def extract_events(schema)
    return [] unless schema

    # Ищем поле 'event' и его enum
    properties = schema.properties || {}
    event_prop = properties['event'] || properties['type']
    return [] unless event_prop && event_prop.respond_to?(:enum)

    event_prop.enum || []
  end

  def map_event_to_status(event)
    case event
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
end