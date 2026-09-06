#!/usr/bin/env ruby
# frozen_string_literal: true

require 'faraday'
require 'json'
require 'ostruct'
require 'base64'
require 'securerandom'

# --------------------------------------------------------------
# 1. Базовый класс BaseService
# --------------------------------------------------------------
class BaseService
  attr_reader :client

  def initialize(client)
    @client = client
  end

  def success(data = nil)
    OpenStruct.new(success?: true, failed?: false, data: data, error_key: nil, message: nil)
  end

  def failure(error_key, message = nil)
    OpenStruct.new(success?: false, failed?: true, data: nil, error_key: error_key, message: message)
  end

  def check_conditions(_operation, _request_method)
    success
  end

  def auth_headers
    shop_id = ENV.fetch('YOOKASSA_SHOP_ID')
    secret_key = ENV.fetch('YOOKASSA_SECRET_KEY')
    {
      'Authorization' => "Basic #{Base64.strict_encode64("#{shop_id}:#{secret_key}")}",
      'Content-Type' => 'application/json'
    }
  end

  def encrypt_sensitive_data(payload) = payload
  def decrypt_sensitive_data(payload) = payload
  def encrypt_field(value) = value
  def decrypt_field(value) = value
end

# --------------------------------------------------------------
# 2. HTTP-клиент для YooKassa
# --------------------------------------------------------------
class YooKassaClient
  def initialize(shop_id, secret_key)
    @shop_id = shop_id
    @secret_key = secret_key
    @connection = Faraday.new do |conn|
      conn.request :authorization, :basic, shop_id, secret_key
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      conn.adapter Faraday.default_adapter
    end
  end

  def post(url, json: nil, headers: nil)
    response = @connection.post(url) do |req|
      req.headers = headers if headers
      req.body = json if json
    end
    build_response(response)
  rescue Faraday::Error => e
    OpenStruct.new(status: 500, body: { 'error' => e.message })
  end

  def get(url, headers: nil)
    response = @connection.get(url) do |req|
      req.headers = headers if headers
    end
    build_response(response)
  rescue Faraday::Error => e
    OpenStruct.new(status: 500, body: { 'error' => e.message })
  end

  private

  def build_response(faraday_response)
    OpenStruct.new(
      status: faraday_response.status,
      body: faraday_response.body || {}
    )
  end
end

# --------------------------------------------------------------
# 3. Класс провайдера (с реализованным process_callback)
# --------------------------------------------------------------
module Provider
  class YoomoneyApiReferenceService < BaseService
    BASE_URL = ENV.fetch('YOOMONEY_API_REFERENCE_BASE_URL', 'https://api.yookassa.ru/v3')

    STATUS_MAP = {
      'pending' => 'in_progress',
      'waiting_for_capture' => 'in_progress',
      'succeeded' => 'approved',
      'canceled' => 'rejected'
    }.freeze

    ERROR_MAP = {
      400 => 'validation_error',
      401 => 'unauthorized',
      403 => 'forbidden',
      500 => 'internal_error',
      404 => 'not_found',
      429 => 'rate_limit'
    }.freeze

    def create_request(operation, request_method = 'create')
      case request_method
      when 'deposit'
        payload = build_deposit_payload(operation)
        endpoint = '/payments'
      when 'payout', 'create'
        payload = build_payout_payload(operation)
        endpoint = '/payouts'
      else
        return failure(:unprocessable_entity, 'unknown_request_method')
      end

      headers = auth_headers
      if operation.respond_to?(:id) && !operation.id.to_s.empty?
        headers['Idempotence-Key'] = operation.id.to_s
      end

      response = client.post("#{BASE_URL}#{endpoint}", json: payload, headers: headers)

      unless response.status.between?(200, 299)
        # Для диагностики выводим тело ошибки
        puts "ERROR RESPONSE BODY: #{response.body.inspect}" if response.status == 400
        error_key = ERROR_MAP[response.status] || 'unknown_error'
        return failure(error_key, "provider.http_error_#{response.status}")
      end

      parse_create_response(operation, response, request_method)
    end

    def fetch_status(operation)
      response = client.get("#{BASE_URL}/payments/#{operation.provider_operation_id}", headers: auth_headers)

      unless response.status.between?(200, 299)
        error_key = ERROR_MAP[response.status] || 'unknown_error'
        return failure(error_key, "provider.http_error_#{response.status}")
      end

      mapped_status = map_status(response.body['status'])
      success(mapped_status)
    end

    # ----------------------------------------------------------
    # Реализация process_callback
    # ----------------------------------------------------------
    def process_callback(payload)
      return failure(:unprocessable_entity, 'invalid_payload_format') unless payload.is_a?(Hash)

      event = payload['event']
      object = payload['object']

      if event.nil? || object.nil?
        return failure(:unprocessable_entity, 'missing_event_or_object')
      end

      unless event.start_with?('payment.')
        return failure(:unprocessable_entity, 'unsupported_event_type')
      end

      payment_id = object['id']
      if payment_id.to_s.empty?
        return failure(:unprocessable_entity, 'missing_payment_id')
      end

      provider_status = object['status']
      if provider_status.nil?
        return failure(:unprocessable_entity, 'missing_payment_status')
      end

      mapped_status = map_status(provider_status)
      if mapped_status == 'unknown'
        return failure(:unprocessable_entity, "unknown_provider_status: #{provider_status}")
      end

      success({
        event: event,
        payment_id: payment_id,
        status: mapped_status,
        provider_status: provider_status,
        raw: payload
      })
    end

    def check_conditions(operation, request_method)
      base_result = super
      return base_result if base_result.failed?

      return success if operation.payout_requisite.nil?

      deal_id = operation.payout_requisite.dig('deal', 'id')
      if deal_id.to_s.empty?
        return failure(:unprocessable_entity, 'id_required')
      end
      if deal_id.to_s.length < 36
        return failure(:unprocessable_entity, 'id_too_short')
      end
      if deal_id.to_s.length > 50
        return failure(:unprocessable_entity, 'id_too_long')
      end

      success
    end

    private

    def build_payout_payload(operation)
      {
        amount: (operation.amount * 100).to_i,
        payout_destination_data: operation.payout_requisite&.dig('payout_destination_data'),
        payout_token: operation.payout_requisite&.dig('payout_token'),
        payment_method_id: operation.payout_requisite&.dig('payment_method_id'),
        description: operation.payout_requisite&.dig('description'),
        deal: operation.payout_requisite&.dig('deal'),
        personal_data: operation.payout_requisite&.dig('personal_data'),
        metadata: operation.payout_requisite&.dig('metadata')
      }.compact
    end

    def build_deposit_payload(operation)
      {
        amount: {
          value: format('%.2f', operation.amount),
          currency: 'RUB'
        },
        description: operation.deposit_requisite&.dig('description'),
        receipt: operation.deposit_requisite&.dig('receipt'),
        payment_token: operation.deposit_requisite&.dig('payment_token'),
        payment_method_id: operation.deposit_requisite&.dig('payment_method_id'),
        payment_method_data: operation.deposit_requisite&.dig('payment_method_data'),
        confirmation: operation.deposit_requisite&.dig('confirmation'),
        save_payment_method: operation.deposit_requisite&.dig('save_payment_method'),
        capture: operation.deposit_requisite&.dig('capture'),
        client_ip: operation.deposit_requisite&.dig('client_ip'),
        metadata: operation.deposit_requisite&.dig('metadata'),
        airline: operation.deposit_requisite&.dig('airline'),
        transfers: operation.deposit_requisite&.dig('transfers'),
        deal: operation.deposit_requisite&.dig('deal'),
        merchant_customer_id: operation.deposit_requisite&.dig('merchant_customer_id'),
        payment_order: operation.deposit_requisite&.dig('payment_order'),
        receiver: operation.deposit_requisite&.dig('receiver'),
        statements: operation.deposit_requisite&.dig('statements'),
        pos_link: operation.deposit_requisite&.dig('pos_link')
      }.compact
    end

    def parse_create_response(operation, response, request_method)
      success(response.body)
    end

    def map_status(provider_status)
      STATUS_MAP[provider_status] || 'unknown'
    end
  end
end

# --------------------------------------------------------------
# 4. Тестовый запуск
# --------------------------------------------------------------

ENV['YOOMONEY_API_REFERENCE_BASE_URL'] = 'https://api.yookassa.ru/v3'
ENV['YOOKASSA_SHOP_ID'] = '1457056'
ENV['YOOKASSA_SECRET_KEY'] = 'test_fIRk360LBI0KoGyZy-nPanRhkS08tkjjw6atR9gNGc8'

client = YooKassaClient.new(
  ENV['YOOKASSA_SHOP_ID'],
  ENV['YOOKASSA_SECRET_KEY']
)

service = Provider::YoomoneyApiReferenceService.new(client)

def build_deposit_operation
  deal_id = SecureRandom.uuid

  OpenStruct.new(
    id: "test-#{Time.now.to_i}",
    amount: 100.00,
    payout_requisite: {
      'deal' => { 'id' => deal_id }
    },
    deposit_requisite: {
      'description' => 'Test payment via real API',
      'payment_method_data' => {
        'type' => 'bank_card',
        'card' => {
          'number' => '5555555555554444',
          'expiry_month' => '12',
          'expiry_year' => '2025',
          'csc' => '123'
        }
      },
      'confirmation' => {
        'type' => 'redirect',
        'return_url' => 'https://example.com/return'
      },
      'save_payment_method' => false,
      'capture' => true,
      'client_ip' => '127.0.0.1',
      'metadata' => { 'test' => true }
    },
    provider_operation_id: nil
  )
end

operation = build_deposit_operation

puts "=== Проверка условий ==="
result = service.check_conditions(operation, 'deposit')
if result.success?
  puts "✅ Условия выполнены"
else
  puts "❌ Ошибка: #{result.error_key} - #{result.message}"
  exit
end

puts "\n=== Создание платежа (deposit) ==="
result = service.create_request(operation, 'deposit')
if result.failed?
  puts "❌ Ошибка: #{result.error_key} - #{result.message}"
  exit
end

puts "✅ Платёж создан успешно!"
payment_data = result.data
puts "ID платежа: #{payment_data['id']}"
puts "Статус: #{payment_data['status']}"
puts "Ссылка на подтверждение: #{payment_data.dig('confirmation', 'confirmation_url')}"

operation.provider_operation_id = payment_data['id']

puts "\n=== Получение статуса платежа ==="
result = service.fetch_status(operation)
if result.success?
  puts "✅ Статус (маппинг): #{result.data}"
else
  puts "❌ Ошибка: #{result.error_key} - #{result.message}"
end

puts "\n=== Обработка callback (с тестовым payload) ==="

test_callback_payload = {
  'event' => 'payment.succeeded',
  'object' => {
    'id' => payment_data['id'],
    'status' => 'succeeded'
  }
}
result = service.process_callback(test_callback_payload)
if result.success?
  puts "✅ Callback обработан успешно!"
  puts "Данные: #{result.data.inspect}"
else
  puts "❌ Ошибка: #{result.error_key} - #{result.message}"
end