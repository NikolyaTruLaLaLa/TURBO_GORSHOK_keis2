# frozen_string_literal: true

require_relative 'heuristic_handler'
require 'erb'

class DigitalSigningHandler < HeuristicHandler
  def handle(manifest)
    heuristic_entry = manifest.heuristic_data.find { |h| h[:name] == 'DigitalSigningHeuristic' }
    return '' unless heuristic_entry

    data = heuristic_entry[:finded_data]
    # data: { "POST /payouts" => { signature_header: "X-Signature", timestamp_header: "X-Timestamp", algorithm: "HMAC-SHA256", ... } }
    # Берём первый эндпоинт с подписью
    endpoint_data = data.values.first
    return '' unless endpoint_data

    algorithm = endpoint_data[:algorithm]
    signature_header = endpoint_data[:signature_header]
    timestamp_header = endpoint_data[:timestamp_header]
    nonce_header = endpoint_data[:nonce_header]

    template_path = File.join(__dir__, '../templates/methods/_signature_headers.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result(binding)
  end
end
