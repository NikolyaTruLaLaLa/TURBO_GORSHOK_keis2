# base_service.rb
require 'faraday'
require 'json'
require 'base64'
require 'securerandom'
require 'ostruct'

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
    #conn.response :logger, nil, headers: true, bodies: true   # добавить эту строку
    conn.adapter Faraday.default_adapter
  end
end

  # Basic Auth для ЮKassa
  def auth_headers
  {
    'Authorization' => 'Basic MTQ1NzA1Njp0ZXN0X2ZJUmszNjBMQkkwS29HeVp5LW5QYW5SaGtTMDh0a2pqdzZhdFI5Z05HYzg=',
    'Content-Type' => 'application/json',
    'Idempotence-Key' => 'op_test_001'
  }
end

  def failure(code, message)
    ServiceResult.new(success: false, error: { code: code, message: message })
  end

  def success(data = {})
    ServiceResult.new(success: true, data: data)
  end

  def get_request(url, headers)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 30
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri.path)
    headers.each { |k, v| request[k] = v }
    response = http.request(request)
    OpenStruct.new(status: response.code.to_i, body: JSON.parse(response.body), headers: response.to_hash)
  rescue => e
    raise
  end

  def post_request(url, payload, headers)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 30
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    headers.each { |k, v| request[k] = v }
    request.body = payload.to_json

    response = http.request(request)
    # Обёртка для единообразия
    OpenStruct.new(status: response.code.to_i, body: JSON.parse(response.body), headers: response.to_hash)
  rescue => e
    # обработка ошибок
    raise
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