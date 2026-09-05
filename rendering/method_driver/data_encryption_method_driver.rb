# frozen_string_literal: true
require_relative 'method_driver'
require_relative '../heuristic_handler/data_fields_encryption_handler'

class DataEncryptionMethodDriver < MethodDriver
  def generate(manifest)
    handler = DataFieldsEncryptionHandler.new
    handler.handle(manifest)
  end
end