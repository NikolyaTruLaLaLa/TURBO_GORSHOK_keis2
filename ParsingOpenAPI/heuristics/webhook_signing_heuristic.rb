# frozen_string_literal: true

require_relative 'heuristic'
require "openapi3_parser"

class WebhookSigningHeuristic < Heuristic
  HEURISTIC_NAME = 'WebhookSigningHeuristic'

  def classify(data)
    endpoints = data[:endpoints_map] # теперь используем хеш
    return nil if endpoints.nil? || endpoints.empty?

    webhook_endpoints = find_all_webhook_endpoints(endpoints)
    return nil if webhook_endpoints.empty?

    result = {}

    webhook_endpoints.each do |key, endpoint|
      operation = endpoint.operation
      description = operation.description || ''

      next unless description_matches?(description)

      signature_header = find_signature_header(operation)
      next unless signature_header

      algorithm = extract_algorithm(description)
      next unless algorithm

      result[key] = {
        algorithm: algorithm,
        header: signature_header
      }
    end

    check_finded_data(result)
    return nil if result.empty?

    { name: self.class.name, finded_data: result }
  end

  private

  def find_all_webhook_endpoints(endpoints)
    endpoints.select do |key, endpoint|
      method = endpoint.http_method.to_s.downcase
      path   = endpoint.path.downcase
      tags   = endpoint.operation.tags || []

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
