# base_service.rb
require 'faraday'
require 'json'
require 'base64'

# Класс результата, соответствующий контракту
class ServiceResult
  attr_reader :success, :data, :error

  def initialize(success:, data: nil, error: nil)
    @success = success
    @data = data
    @error = error
  end

  def success?
    @success
  end

  def failed?
    !@success
  end
end

class BaseService
  attr_reader :credentials

  def initialize(credentials)
    @credentials = credentials
  end

  # Базовый метод для super в check_conditions
  def check_conditions(operation, request_method)
    ServiceResult.new(success: true)
  end

  # Заглушки для process_callback
  def approve_operation(payout_id)
    # логика одобрения
  end

  def reject_operation(payout_id, error_code)
    # логика отклонения
  end

  def update_operation_status(payout_id, status)
    # логика обновления статуса
  end

  private

  def client
    @client ||= Faraday.new(url: self.class::BASE_URL) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  # Basic Auth для ЮKassa
  def auth_headers
  {
    'Authorization' => 'Basic ' + Base64.strict_encode64("#{credentials.shop_id}:#{credentials.secret_key}")
  }
end

  def failure(code, message)
    ServiceResult.new(success: false, error: { code: code, message: message })
  end

  def success(data = {})
    ServiceResult.new(success: true, data: data)
  end

  def parse_create_response(operation, response, request_method)
    if response.status == 200 || response.status == 201
      body = response.body
      operation.provider_operation_id = body['id'] if operation.respond_to?(:provider_operation_id=)
      # Для платежей ЮKassa возвращает confirmation_url
      if body['confirmation'] && body['confirmation']['confirmation_url']
        return success(operation: operation, confirmation_url: body['confirmation']['confirmation_url'])
      end
      success(operation: operation)
    else
      error_code = ERROR_MAP[response.status] || 'unknown_error'
      error_message = response.body.dig('error', 'description') || response.body['error'] || "HTTP #{response.status}"
      failure(error_code, error_message)
    end
  end

  def map_status(provider_status)
    self.class::STATUS_MAP[provider_status] || 'unknown'
  end
end