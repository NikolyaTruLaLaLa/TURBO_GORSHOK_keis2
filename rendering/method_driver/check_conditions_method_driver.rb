# rendering/method_driver/check_conditions_method_driver.rb
require_relative 'method_driver'
require_relative '../../ParsingOpenAPI/schema_extractor'
require 'erb'

class CheckConditionsMethodDriver < MethodDriver
  def generate(manifest)
    heuristic_entry = manifest.heuristic_data.find { |h| h[:name] == 'CreateEndpointHeuristic' }
    return default_method unless heuristic_entry

    finded_data = heuristic_entry[:finded_data]
    payout_data = finded_data[:payout_create_endpoint]
    return default_method unless payout_data

    schema = payout_data[:request_schema]
    if schema.is_a?(String)
      schema = manifest.schemas_map[schema]
    end
    return default_method unless schema

    validations = generate_validations(schema, 'payout')
    return default_method if validations.empty?

    template_path = File.join(__dir__, '../templates/methods/_check_conditions.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result(binding)
  end

  private

  def default_method
    <<~RUBY
      public

      def check_conditions(operation, request_method)
        base_result = super
        return base_result if base_result.failed?
        # TODO: Add validation logic based on provider schema
        success
      end
    RUBY
  end

  def generate_validations(schema, type, prefix = nil)
    validations = []
    properties = schema.properties || {}
    required = schema.required || []

    properties.each do |name, prop|
      # Определяем выражение для получения значения
      value_expr = if prefix.nil?
                     # Корневое поле: operation.amount, operation.currency, ...
                     "operation.#{name}"
                   else
                     # Вложенное поле: operation.payout_requisite.dig('recipient', 'field')
                     "operation.#{type}_requisite.dig(#{prefix.split('.').map { |p| "'#{p}'" }.join(', ')}, '#{name}')"
                   end

      # Проверка обязательности (только если поле требуется и не amount)
      if required.include?(name) && name != 'amount'
        validations << "if #{value_expr}.blank?\n  return failure(:unprocessable_entity, '#{name}_required')\nend"
      end

      # Проверки ограничений
      validations.concat(generate_field_checks(name, prop, value_expr))

      # Рекурсивно обрабатываем вложенные объекты (например, recipient)
      if prop.type == 'object' && prop.properties
        nested_prefix = prefix ? "#{prefix}.#{name}" : name
        validations.concat(generate_validations(prop, type, nested_prefix))
      end
    end

    validations
  end

  def generate_field_checks(name, prop, value_expr)
    checks = []

    if prop.type == 'integer' || prop.type == 'number'
      if prop.minimum
        checks << "if #{value_expr} < #{prop.minimum}\n  return failure(:unprocessable_entity, '#{name}_too_low')\nend"
      end
      if prop.maximum
        checks << "if #{value_expr} > #{prop.maximum}\n  return failure(:unprocessable_entity, '#{name}_too_high')\nend"
      end
    end

    if prop.type == 'string'
      if prop.min_length && prop.min_length > 0
        checks << "if #{value_expr}.to_s.length < #{prop.min_length}\n  return failure(:unprocessable_entity, '#{name}_too_short')\nend"
      end
      if prop.max_length
        checks << "if #{value_expr}.to_s.length > #{prop.max_length}\n  return failure(:unprocessable_entity, '#{name}_too_long')\nend"
      end
      if prop.pattern
        checks << "unless #{value_expr} =~ /#{prop.pattern}/\n  return failure(:unprocessable_entity, 'invalid_#{name}_format')\nend"
      end
      if prop.enum
        enum_values = prop.enum.map { |v| "'#{v}'" }.join(', ')
        checks << "unless [#{enum_values}].include?(#{value_expr})\n  return failure(:unprocessable_entity, 'invalid_#{name}_value')\nend"
      end
    end

    checks
  end
end
