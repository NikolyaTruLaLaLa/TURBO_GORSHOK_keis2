# frozen_string_literal: true
require_relative 'heuristic'
require "openapi3_parser"

class DigitalSigningHeuristic < Heuristic
  HEURISTIC_NAME = 'DigitalSigningHeuristic'
  HTTP_METHODS = %i[get post put patch delete head options].freeze

  # Все необходимые заголовки и ключевые слова
  SIGNATURE_HEADERS = %w[signature sig hmac digest auth].freeze
  TIMESTAMP_HEADERS = %w[timestamp ts nonce salt].freeze
  DESCRIPTION_KEYWORDS = %w[hmac sha rsa sign verify algorithm signature].freeze
  EXCLUDED_PATHS = %w[webhook callback notification].freeze
  EXCLUDED_TAGS = %w[webhooks].freeze

  def classify(data)
    endpoints = extract_endpoints(data)
    result = {}

    endpoints.each do |ep|
      next if webhook_endpoint?(ep)

      operation = ep[:operation]
      description = operation.description || ''

      headers = extract_headers(operation)
      next if headers.empty?

      signature_headers = find_signature_headers(headers)
      next if signature_headers.empty?

      next unless description_matches?(description)

      security_schemes = operation.security || []

      endpoint_key = "#{ep[:method].to_s.upcase} #{ep[:path]}"

      result[endpoint_key] = {
        signature_header: signature_headers.first,
        timestamp_header: find_timestamp_header(headers),
        nonce_header: find_nonce_header(headers),
        algorithm: extract_algorithm(description) || 'HMAC-SHA256',
        has_security: !security_schemes.empty?
      }
    end

    check_finded_data(result)
    return nil if result.empty?
    { HEURISTIC_NAME => result }
  end

  def webhook_endpoint?(ep)
    path = ep[:path].downcase
    tags = ep[:operation].tags || []
    operation_id = ep[:operation].operation_id&.downcase || ''
    return true if EXCLUDED_PATHS.any? { |keyword| path.include?(keyword) }
    return true if tags.any? { |tag| EXCLUDED_TAGS.include?(tag.downcase) }
    return true if EXCLUDED_PATHS.any? { |keyword| operation_id.include?(keyword) }
    false
  end

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

  # Извлекает все заголовки из параметров операции
  def extract_headers(operation)
    headers = {}
    operation.parameters.each do |param|
      next unless param.in == 'header' && param.name

      name = param.name.downcase
      headers[name] = {
        name: param.name,
        description: param.description || '',
        required: param.required? || false,
        schema: param.schema
      }
    end
    headers
  end

  def find_signature_headers(headers)
    signature_headers = []

    headers.each do |name, data|
      if SIGNATURE_HEADERS.any? { |keyword| name.include?(keyword) }
        next if name.include?('authorization')
        signature_headers << data[:name]
      end
    end

    signature_headers
  end

  # Проверяет описание на наличие ключевых слов
  def description_matches?(description)
    DESCRIPTION_KEYWORDS.any? { |kw| description.downcase.include?(kw) }
  end

  # Извлекает алгоритм из описания
  def extract_algorithm(description)
    patterns = [
      /HMAC-SHA256/i,
      /HMAC-SHA1/i,
      /RSA-SHA256/i,
      /SHA256/i,
      /SHA1/i,
      /algorithm\s*[:=]\s*([\w-]+)/i,
      /signature\s+algorithm\s+is\s+([\w-]+)/i,
      /using\s+(HMAC-SHA256|HMAC-SHA1|RSA-SHA256|SHA256|SHA1)/i
    ]

    patterns.each do |pattern|
      match = description.match(pattern)
      return match[1] || match[0] if match
    end
    nil
  end

end

data = Openapi3Parser.load_file(File.expand_path("../../yaml_examples/provider_api.yaml", __dir__))
heuristic = DigitalSigningHeuristic.new()
result = heuristic.classify(data)
puts "Result: #{result.inspect}" if result