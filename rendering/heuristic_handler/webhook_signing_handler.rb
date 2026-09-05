# rendering/heuristic_handler/webhook_signing_handler.rb
require_relative 'heuristic_handler'
require 'erb'

class WebhookSigningHandler < HeuristicHandler
  def handle(manifest)
    heuristic_entry = manifest.heuristic_data.find { |h| h[:name] == 'WebhookSigningHeuristic' }
    return '' unless heuristic_entry

    data = heuristic_entry[:finded_data]
    # data имеет вид { "POST /webhooks/payout" => { algorithm: "HMAC-SHA256", header: "X-NovaPay-Signature" } }
    # Берём первый (или единственный) вебхук
    endpoint_data = data.values.first
    return '' unless endpoint_data

    algorithm = endpoint_data[:algorithm]
    header = endpoint_data[:header]

    template_path = File.join(__dir__, '../templates/methods/_verify_signature.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result(binding)
  end
end
