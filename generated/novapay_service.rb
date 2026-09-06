class Provider::NovapayPayoutApiService < BaseService
  BASE_URL = ENV.fetch('NOVAPAY_PAYOUT_API_BASE_URL', 'https://api.novapay.example/v1')

  STATUS_MAP = {
    'payout.completed' => 'approved',
    'payout.failed' => 'rejected',
    'payout.processing' => 'in_progress',
    'payout.cancelled' => 'rejected',
  }.freeze

  ERROR_MAP = {
    400 => 'validation_error',
    401 => 'unauthorized',
    402 => 'insufficient_balance',
    409 => 'internal_error',
    422 => 'validation_error',
    429 => 'rate_limit',
    500 => 'internal_error',
    404 => 'not_found',
  }.freeze

  def create_request(operation, request_method = 'create')
  payload = build_payout_payload(operation)
  endpoint = '/payouts'

  headers = auth_headers
  if operation.respond_to?(:id) && operation.id.present?
    headers['Idempotency-Key'] = operation.id.to_s
  end

  response = client.post("#{BASE_URL}#{endpoint}", json: payload, headers: headers)

  unless response.status.between?(200, 299)
    error_key = ERROR_MAP[response.status] || 'unknown_error'
    return failure(error_key, "provider.http_error_#{response.status}")
  end

  parse_create_response(operation, response, request_method)
end

private

def build_payout_payload(operation)
  {
    amount: (operation.amount * 100).to_i,
    currency: operation.currency,
    external_id: operation.id,
    recipient: {
      type: operation.payout_requisite&.dig('type'),
      phone: operation.payout_requisite&.dig('phone'),
      bank_code: operation.payout_requisite&.dig('bank_code'),
      bank_name: operation.payout_requisite&.dig('bank_name'),
      card_number: operation.payout_requisite&.dig('card_number')
    },
  }.compact
end



  public

  def fetch_status(operation)
    response = client.get("\#{BASE_URL}/payouts/#{operation.provider_operation_id}", headers: auth_headers)

    unless response.status.between?(200, 299)
      error_key = ERROR_MAP[response.status] || 'unknown_error'
      return failure(error_key, "provider.http_error_#{response.status}")
    end

    map_status(response.body['status'])
  end

  private

  def map_status(provider_status)
    STATUS_MAP[provider_status] || 'unknown'
  end

public

def process_callback(payload)
  verify_signature!(payload)
  event = payload['event']
  payout_id = payload['payout_id']

  case event
  when 'payout.completed'
    approve_operation(payout_id)
  when 'payout.failed'
    reject_operation(payout_id, payload.dig('error', 'code'))
  when 'payout.processing'
    update_operation_status(payout_id, 'in_progress')
  when 'payout.cancelled'
    reject_operation(payout_id, payload.dig('error', 'code'))
  else
    failure(:unprocessable_entity, 'unknown_event')
  end
rescue Provider::SignatureError
  failure(:unauthorized, 'provider.invalid_signature')
rescue => e
  failure(:internal_error, 'provider.unexpected_error')
end

public

def check_conditions(operation, request_method)
  base_result = super
  return base_result if base_result.failed?

  if operation.amount < 100000
  return failure(:unprocessable_entity, 'amount_too_low')
end
  if operation.currency.blank?
  return failure(:unprocessable_entity, 'currency_required')
end
  unless ['RUB'].include?(operation.currency)
  return failure(:unprocessable_entity, 'invalid_currency_value')
end
  if operation.external_id.blank?
  return failure(:unprocessable_entity, 'external_id_required')
end
  if operation.external_id.to_s.length > 64
  return failure(:unprocessable_entity, 'external_id_too_long')
end
  if operation.recipient.blank?
  return failure(:unprocessable_entity, 'recipient_required')
end
  if operation.payout_requisite.dig('recipient', 'type').blank?
  return failure(:unprocessable_entity, 'type_required')
end
  unless ['sbp', 'card'].include?(operation.payout_requisite.dig('recipient', 'type'))
  return failure(:unprocessable_entity, 'invalid_type_value')
end
  if operation.payout_requisite.dig('recipient', 'phone').blank?
  return failure(:unprocessable_entity, 'phone_required')
end
  unless operation.payout_requisite.dig('recipient', 'phone') =~ /^7\d{10}$/
  return failure(:unprocessable_entity, 'invalid_phone_format')
end

  success
end

private

def verify_signature!(payload)
  provided_signature = request.headers['X-NovaPay-Signature']
  return unless provided_signature

  secret = credentials.webhook_secret
  expected_signature = OpenSSL::HMAC.hexdigest('hmacsha256', secret, payload.to_json)
  unless ActiveSupport::SecurityUtils.secure_compare(expected_signature, provided_signature)
    raise Provider::SignatureError, "Invalid signature"
  end
end



private

def encrypt_sensitive_data(payload)
  encrypted_payload = payload.dup
  if encrypted_payload.key?('card_number')
    encrypted_payload['card_number'] = encrypt_field(encrypted_payload['card_number'])
  end
  encrypted_payload
end

def encrypt_field(value)
  # TODO: Implement encryption logic
  value
end

def decrypt_sensitive_data(payload)
  decrypted_payload = payload.dup
  if decrypted_payload.key?('card_number')
    decrypted_payload['card_number'] = decrypt_field(decrypted_payload['card_number'])
  end
  decrypted_payload
end

def decrypt_field(value)
  # TODO: Implement decryption logic
  value
end
end