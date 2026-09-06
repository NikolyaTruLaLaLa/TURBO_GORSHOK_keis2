# frozen_string_literal: true

require_relative 'heuristic_handler'
require 'erb'

class DataFieldsEncryptionHandler < HeuristicHandler
  def handle(manifest)
    heuristic_entry = manifest.heuristic_data.find { |h| h[:name] == 'DataFieldsEncryptionHeuristic' }
    return <<~RUBY unless heuristic_entry
      # TODO: Webhook signing not detected in specification
    RUBY

    data = heuristic_entry[:finded_data]
    sensitive_fields = data[:sensitive_fields] || {}
    puts "DataFieldsEncryptionHandler: sensitive_fields = #{sensitive_fields.inspect}"
    return '' if sensitive_fields.empty?

    # Генерируем методы шифрования для чувствительных полей
    template_path = File.join(__dir__, '../templates/methods/_sensitive_data_encryption.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result(binding)
  end
end
