require 'faraday'
require 'json'

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

  def check_conditions(operation, request_method)
    success
  end

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
    conn.response :json # или просто conn.response :json
    conn.adapter Faraday.default_adapter
  end
end

  def auth_headers
    { 'X-API-Key' => credentials.api_key }
  end

  def failure(code, message)
    ServiceResult.new(success: false, error: { code: code, message: message })
  end

  def success(data = {})
    ServiceResult.new(success: true, data: data)
  end

  def parse_create_response(operation, response, request_method)
    if response.status == 201
      operation.provider_operation_id = response.body['id'] if operation.respond_to?(:provider_operation_id=)
      success(operation)
    else
      failure(ERROR_MAP[response.status] || 'unknown_error', response.body.dig('error', 'message'))
    end
  end

  def map_status(provider_status)
    self.class::STATUS_MAP[provider_status] || 'unknown'
  end
end