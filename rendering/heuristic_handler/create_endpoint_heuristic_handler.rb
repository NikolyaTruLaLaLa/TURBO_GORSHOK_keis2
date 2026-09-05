# frozen_string_literal: true

require_relative 'heuristic_handler'
require 'erb'

class CreateEndpointHeuristicHandler < HeuristicHandler
  def handle(manifest)
    heuristic_entry = manifest.heuristic_data.find { |h| h[:name] == 'CreateEndpointHeuristic' }
    return default_method if heuristic_entry.nil?

    finded_data = heuristic_entry[:finded_data]
    payout_data = finded_data[:payout_create_endpoint]
    deposit_data = finded_data[:deposit_create_endpoint]

    code = +''
    code << render_create_request(payout_data, deposit_data)
    code << "\n\n" if !code.empty?
    code << render_payload_builders(payout_data, deposit_data, manifest.schemas_map)
    code
  end

  private

  def default_method
    "def create_request(operation, request_method = 'create')\n  raise NotImplementedError, \"No create endpoint found\"\nend"
  end

  def render_create_request(payout_data, deposit_data)
    has_payout = !payout_data.nil?
    has_deposit = !deposit_data.nil?
    payout_path = payout_data ? payout_data[:path] : nil
    deposit_path = deposit_data ? deposit_data[:path] : nil

    template = File.read(File.join(__dir__, '../templates/methods/_create_request.erb'))
    ERB.new(template, trim_mode: '-').result(binding)
  end

  def render_payload_builders(payout_data, deposit_data, schemas_map)
    puts "payout_data: #{payout_data.inspect}"
    puts "deposit_data: #{deposit_data.inspect}"
    code = +''

    if payout_data && payout_data[:request_schema]
      schema = payout_data[:request_schema]
      # если это строка – ищем в schemas_map
      if schema.is_a?(String)
        schema = schemas_map[schema]
      end
      if schema
        fields = extract_fields(schema)
        code << render_payload_builder('build_payout_payload', fields, 'payout')
      else
        code << fallback_payload_builder('build_payout_payload')
      end
      code << "\n\n"
    end

    # аналогично для deposit
    if deposit_data && deposit_data[:request_schema]
      schema = deposit_data[:request_schema]
      if schema.is_a?(String)
        schema = schemas_map[schema]
      end
      if schema
        fields = extract_fields(schema)
        code << render_payload_builder('build_deposit_payload', fields, 'deposit')
      else
        code << fallback_payload_builder('build_deposit_payload')
      end
      code << "\n\n"
    end

    code
  end

  def render_payload_builder(method_name, fields, type)
    # Мы передаём локальную переменную field_mapping, которая является методом этого хэндлера
    # или мы можем передать её как lambda.
    # Чтобы использовать в ERB, сделаем её доступной через binding.
    @field_mapping_method = ->(field, type) { field_mapping(field, type) }
    template = File.read(File.join(__dir__, '../templates/methods/_payload_builder.erb'))
    ERB.new(template, trim_mode: '-').result(binding)
  end

  def fallback_payload_builder(method_name)
    <<~RUBY
      private

      def #{method_name}(operation)
        # TODO: manual mapping – schema not found
        {}
      end
    RUBY
  end

  # Рекурсивное извлечение полей из схемы
  def extract_fields(schema_node)
    return [] unless schema_node

    properties = schema_node.properties || {}
    required = schema_node.required || []

    properties.map do |name, prop_schema|
      {
        name: name,
        type: prop_schema.type,
        required: required.include?(name),
        format: prop_schema.format,
        properties: prop_schema.type == 'object' ? extract_fields(prop_schema) : nil
      }
    end
  end

  # Функция для маппинга поля в Ruby-код извлечения из operation
  def field_mapping(field, type)
    name = field[:name]
    case name
    when 'amount'
      "(operation.amount * 100).to_i"
    when 'currency'
      "operation.currency"
    when 'external_id'
      "operation.id"
    when 'recipient'
      # Если есть вложенные поля
      if field[:properties]
        hash_parts = field[:properties].map do |nested|
          "      #{nested[:name]}: #{field_mapping(nested, type)}"
        end.join(",\n")
        "{\n#{hash_parts}\n    }"
      else
        "operation.#{type}_requisite&.dig('#{name}')"
      end
    else

      "operation.#{type}_requisite&.dig('#{name}')"
    end
  end
end