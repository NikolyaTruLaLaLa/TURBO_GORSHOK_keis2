# frozen_string_literal: true
require_relative 'method_driver'
require_relative '../heuristic_handler/digital_signing_handler'

class DigitalSigningMethodDriver < MethodDriver
  def generate(manifest)
    handler = DigitalSigningHandler.new
    handler.handle(manifest)
  end
end