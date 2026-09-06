require_relative 'method_driver'
require_relative '../../ParsingOpenAPI/schema_extractor'
require 'erb'

class ProcessCallbackMethodDriver < MethodDriver
    def generate(manifest)
    webhook_endpoint = manifest.webhooks_map.values.first
    return default_method unless webhook_endpoint

    schema = SchemaExtractor.request_schema(webhook_endpoint.operation)
    events = extract_events(schema)

    if events.empty?
      return default_method
    end

    template_path = File.join(__dir__, '../templates/methods/_process_callback.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result(binding)
  end

  private

  def default_method
    <<~RUBY
      public

      def process_callback(payload)
        # TODO: Implement webhook processing according to provider specification
        failure(:unprocessable_entity, 'webhook_not_implemented')
      end
    RUBY
  end

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
