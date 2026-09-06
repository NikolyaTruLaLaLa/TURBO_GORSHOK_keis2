require 'ostruct'
require_relative 'base_service'
require_relative 'novapay_service' # путь к вашему классу
require_relative 'test_operation'

class String
  def blank?
    strip.empty?
  end
end

class NilClass
  def blank?
    true
  end
end

class Hash
  def blank?
    empty?
  end
end

class Array
  def blank?
    empty?
  end
end

ENV['NOVAPAY_PAYOUT_API_BASE_URL'] = 'https://api.sandbox.novapay.example/v1'

credentials = OpenStruct.new(api_key: 'your_sandbox_api_key', webhook_secret: 'your_webhook_secret')

service = NovapayPayoutApiService.new(credentials)
operation = TestOperation.new

# 1. Проверка условий (теперь работает)
result = service.check_conditions(operation, 'create')
puts "Check conditions: #{result.inspect}"

# 2. Создание выплаты
result = service.create_request(operation)
puts "Create request: #{result.inspect}"
puts "Provider operation ID: #{operation.provider_operation_id}" if operation.provider_operation_id

# 3. Получение статуса
if operation.provider_operation_id
  status_result = service.fetch_status(operation)
  puts "Fetch status: #{status_result.inspect}"
end