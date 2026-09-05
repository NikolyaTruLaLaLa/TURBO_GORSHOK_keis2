# frozen_string_literal: true

require_relative 'heuristic'
require_relative '../schema_extractor'

class DataFieldsEncryptionHeuristic < Heuristic
  HEURISTIC_NAME = 'DataFieldsEncryptionHeuristic'

  SENSITIVE_FIELD_NAMES = %w[
    card_number pan cvv cvc password secret
    encrypted_data encrypted_payload token
  ].freeze

  ENCRYPTION_KEYWORDS = %w[encrypt decrypt cipher secure].freeze

  def classify(data)
    endpoints_map = data[:endpoints_map]
    sensitive_fields = {}

    endpoints_map.each do |key, endpoint|
      operation = endpoint.operation
      path = endpoint.path
      method = endpoint.http_method.to_s.upcase
      operation_info = { path: path, method: method }

      # requestBody
      schema = SchemaExtractor.request_schema(operation)
      if schema
        traverse_schema(schema, operation_info.merge(direction: 'request'), sensitive_fields)
      end

      # responses
      ['200', '201'].each do |status|
        schema = SchemaExtractor.response_schema(operation, status)
        if schema
          traverse_schema(schema, operation_info.merge(direction: 'response', status_code: status), sensitive_fields)
        end
      end
    end

    check_finded_data(sensitive_fields)
    return nil if sensitive_fields.empty?

    # Возвращаем плоскую структуру для хэндлера
    {
      name: self.class.name,
      finded_data: {
        sensitive_fields: sensitive_fields,
        encryption_used: sensitive_fields.any? { |_, info| info[:encryption_mentioned] }
      }
    }
  end

  private

  def traverse_schema(schema, operation_info, sensitive_fields, path_prefix = '')
    if schema.respond_to?(:resolve)
      schema = schema.resolve
    end

    return unless schema.respond_to?(:properties)

    properties = schema.properties || {}
    properties.each do |prop_name, prop_schema|
      current_path = path_prefix.empty? ? prop_name : "#{path_prefix}.#{prop_name}"

      if sensitive_field?(prop_name, prop_schema)
        add_sensitive_field(sensitive_fields, prop_name, current_path, operation_info, prop_schema)
      end

      if prop_schema.respond_to?(:properties) && prop_schema.properties
        traverse_schema(prop_schema, operation_info, sensitive_fields, current_path)
      elsif prop_schema.type == 'array' && prop_schema.items
        traverse_schema(prop_schema.items, operation_info, sensitive_fields, current_path)
      end
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
