# frozen_string_literal: true
require_relative 'heuristic'

class DigitalSigningHeuristic < Heuristic
  HEURISTIC_NAME = 'DigitalSigningHeuristic'

  # Все необходимые заголовки и ключевые слова
  SIGNATURE_HEADERS = %w[signature sig hmac digest auth].freeze
  TIMESTAMP_HEADERS = %w[timestamp ts nonce salt].freeze
  DESCRIPTION_KEYWORDS = %w[hmac sha rsa sign verify algorithm signature].freeze
  EXCLUDED_PATHS = %w[webhook callback notification].freeze
  EXCLUDED_TAGS = %w[webhooks].freeze

  def classify(data)
    endpoints = extract_endpoints(data) # передаём data[:endpoints_map] или всё data
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
    { name: self.class.name, finded_data: result }
  end

  private

  def extract_endpoints(data)
    endpoints = []
    endpoints_map = data[:endpoints_map] || data # если передана вся data, берём :endpoints_map
    endpoints_map.each do |key, endpoint|
      endpoints << {
        path: endpoint.path,
        method: endpoint.http_method,
        operation: endpoint.operation
      }
    end
    endpoints
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

  def find_timestamp_header(headers)
    headers.each do |name, data|
      return data[:name] if TIMESTAMP_HEADERS.any? { |keyword| name.include?(keyword) }
    end
    nil
  end

  def find_nonce_header(headers)
    # Ищем nonce, salt, random и т.п.
    nonce_keywords = %w[nonce salt random]
    headers.each do |name, data|
      return data[:name] if nonce_keywords.any? { |keyword| name.include?(keyword) }
    end
    nil
  end

  def description_matches?(description)
    DESCRIPTION_KEYWORDS.any? { |kw| description.downcase.include?(kw) }
  end

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