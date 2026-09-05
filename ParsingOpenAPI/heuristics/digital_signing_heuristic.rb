# frozen_string_literal: true
require_relative 'heuristic'
require 'openapi3_parser'

class DataFieldsEncryptionHeuristic < Heuristic
  HEURISTIC_NAME = 'DataFieldsEncryptionHeuristic'

  SENSITIVE_FIELD_NAMES = %w[
    card_number pan cvv cvc password secret
    encrypted_data encrypted_payload token
  ].freeze

  ENCRYPTION_KEYWORDS = %w[encrypt decrypt cipher secure].freeze
  HTTP_METHODS = %i[get post put patch delete head options].freeze

  def classify(data)
    endpoints = extract_endpoints(data)
    sensitive_fields = {}

    endpoints.each do |ep|
      operation = ep[:operation]
      operation_info = { path: ep[:path], method: ep[:method].to_s.upcase }

      if operation.request_body
        operation.request_body.content.each do |_media_type, media_type_obj|
          schema = media_type_obj.schema
          next unless schema
          traverse_schema(schema, operation_info.merge(direction: 'request'), sensitive_fields)
        end
      end

      # Анализируем responses
      operation.responses.each do |status_code, response|
        next unless response.content
        response.content.each do |_media_type, media_type_obj|
          schema = media_type_obj.schema
          next unless schema
          traverse_schema(schema, operation_info.merge(direction: 'response', status_code: status_code), sensitive_fields)
        end
      end
    end

    check_finded_data(sensitive_fields)
    return nil if sensitive_fields.empty?

    {
      HEURISTIC_NAME => {
        sensitive_fields: sensitive_fields,
        encryption_used: sensitive_fields.any? { |_, info| info[:encryption_mentioned] }
      }
    }
  end

  private

  def extract_endpoints(data)
    endpoints = []
    data.paths.each do |path, path_item|
      HTTP_METHODS.each do |method|
        operation = path_item.public_send(method)
        next unless operation
        endpoints << { path: path, method: method, operation: operation }
      end
    end
    endpoints
  end

  # Разрешение ссылок
  def traverse_schema(schema, operation_info, sensitive_fields, path_prefix = '')
    schema = schema.resolve if schema.respond_to?(:resolve)
    return unless schema.respond_to?(:properties)

    if schema.properties
      schema.properties.each do |prop_name, prop_schema|
        current_path = path_prefix.empty? ? prop_name : "#{path_prefix}.#{prop_name}"

        if sensitive_field?(prop_name, prop_schema)
          add_sensitive_field(sensitive_fields, prop_name, current_path, operation_info, prop_schema)
        end

        # Рекурсивно обходим вложенные объекты
        if prop_schema.respond_to?(:properties) && prop_schema.properties
          traverse_schema(prop_schema, operation_info, sensitive_fields, current_path)
        elsif prop_schema.type == 'array' && prop_schema.items
          traverse_schema(prop_schema.items, operation_info, sensitive_fields, current_path)
        end
      end
    end

    if schema.type == 'array' && schema.items
      traverse_schema(schema.items, operation_info, sensitive_fields, path_prefix)
    end

    %i[any_of one_of all_of].each do |key|
      next unless schema.respond_to?(key)
      schemas = schema.public_send(key)
      next unless schemas
      schemas.each do |sub_schema|
        traverse_schema(sub_schema, operation_info, sensitive_fields, path_prefix)
      end
    end
  end

  def sensitive_field?(field_name, field_schema)
    name_match = SENSITIVE_FIELD_NAMES.any? { |kw| field_name.downcase.include?(kw) }

    if field_name.downcase.include?('token') && field_schema.description
      return false if field_schema.description.downcase =~ /(id|identifier|reference|jwt|access|refresh)/
    end

    description_match = field_schema.description &&
                        ENCRYPTION_KEYWORDS.any? { |kw| field_schema.description.downcase.include?(kw) }

    name_match || description_match
  end

  def add_sensitive_field(sensitive_fields, field_name, full_path, operation_info, field_schema)
    unless sensitive_fields.key?(field_name)
      sensitive_fields[field_name] = { operations: [], encryption_mentioned: false }
    end

    op_key = "#{operation_info[:method]} #{operation_info[:path]} (#{operation_info[:direction]})"
    unless sensitive_fields[field_name][:operations].include?(op_key)
      sensitive_fields[field_name][:operations] << op_key
    end

    if field_schema.description && ENCRYPTION_KEYWORDS.any? { |kw| field_schema.description.downcase.include?(kw) }
      sensitive_fields[field_name][:encryption_mentioned] = true
    end
  end
end

data = Openapi3Parser.load_file(File.expand_path("../../yaml_examples/provider_api.yaml", __dir__))
heuristic = DataFieldsEncryptionHeuristic.new()
result = heuristic.classify(data)
puts "Result: #{result.inspect}" if result