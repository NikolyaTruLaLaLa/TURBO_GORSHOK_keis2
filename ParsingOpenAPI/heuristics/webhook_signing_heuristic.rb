# frozen_string_literal: true
require_relative 'heuristic'
require "openapi3_parser"

class WebhookSigningHeuristic < Heuristic
  HEURISTIC_NAME = 'WebhookSigningHeuristic'
  HTTP_METHODS = %i[get post put patch delete head options].freeze

  def classify(data)
    endpoints = extract_endpoints(data)
    webhook_endpoints = find_all_webhook_endpoints(endpoints)
    return nil if webhook_endpoints.empty?

    result = {}

    webhook_endpoints.each do |ep|
      operation = ep[:operation]
      description = operation.description || ''

      # Проверяем описание на наличие ключевых слов
      next unless description_matches?(description)

      # Ищем заголовок подписи
      signature_header = find_signature_header(operation)
      next unless signature_header

      # Извлекаем алгоритм из описания
      algorithm = extract_algorithm(description)
      next unless algorithm

      # Формируем ключ эндпоинта
      endpoint_key = "#{ep[:method].to_s.upcase} #{ep[:path]}"
      result[endpoint_key] = algorithm
    end

    check_finded_data(result)
    return nil if result.empty?
    { HEURISTIC_NAME => result }
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

  def find_all_webhook_endpoints(endpoints)
    endpoints.select do |ep|
      method = ep[:method].to_s.downcase
      path   = ep[:path].downcase
      tags   = ep[:operation].tags || []

      (path.include?('webhook') && method == 'post') ||
        tags.any? { |t| t.downcase == 'webhooks' }
    end
  end

  def description_matches?(description)
    keywords = %w[webhook callback notification signature]
    keywords.any? { |kw| description.downcase.include?(kw) }
  end

  def find_signature_header(operation)
    operation.parameters.each do |param|
      next unless param.in == 'header' && param.name

      name = param.name.downcase
      if name.include?('signature') && !name.include?('authorization')
        return param.name
      end
    end
    nil
  end

  def extract_algorithm(description)
    patterns = [
      /HMAC-SHA256/i,
      /HMAC-SHA1/i,
      /RSA-SHA256/i,
      /SHA256/i,
      /SHA1/i,
      /algorithm\s*[:=]\s*([\w-]+)/i,
      /signature\s+algorithm\s+is\s+([\w-]+)/i
    ]

    patterns.each do |pattern|
      match = description.match(pattern)
      return match[1] || match[0] if match
    end
    nil
  end
end

data = Openapi3Parser.load_file(File.expand_path("../../yaml_examples/provider_api.yaml", __dir__))
wb = WebhookSigningHeuristic.new()
result = wb.classify(data)
puts "Result: #{result.inspect}" if result