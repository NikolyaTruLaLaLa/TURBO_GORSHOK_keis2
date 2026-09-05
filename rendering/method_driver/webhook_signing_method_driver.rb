# rendering/method_driver/webhook_signing_method_driver.rb
require_relative 'method_driver'
require_relative '../heuristic_handler/webhook_signing_handler'

class WebhookSigningMethodDriver < MethodDriver
  def generate(manifest)
    handler = WebhookSigningHandler.new
    handler.handle(manifest)
  end
end
