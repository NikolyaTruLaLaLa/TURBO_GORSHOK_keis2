class YoomoneyApiReferenceService < BaseService
  BASE_URL = ENV.fetch('YOOMONEY_API_REFERENCE_BASE_URL', 'https://api.yookassa.ru/v3')

  STATUS_MAP = {
    'pending' => 'in_progress',
    'waiting_for_capture' => 'in_progress',
    'succeeded' => 'approved',
    'canceled' => 'rejected',
  }.freeze

  ERROR_MAP = {
    400 => 'validation_error',
    401 => 'unauthorized',
    403 => 'forbidden',
    500 => 'internal_error',
    404 => 'not_found',
    429 => 'rate_limit',
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
    payout_destination_data: operation.payout_requisite&.dig('payout_destination_data'),
    payout_token: operation.payout_requisite&.dig('payout_token'),
    payment_method_id: operation.payout_requisite&.dig('payment_method_id'),
    description: operation.payout_requisite&.dig('description'),
    deal: operation.payout_requisite&.dig('deal'),
    personal_data: operation.payout_requisite&.dig('personal_data'),
    metadata: operation.payout_requisite&.dig('metadata'),
  }.compact
end

private

def build_deposit_payload(operation)
  {
    amount: (operation.amount * 100).to_i,
    description: operation.deposit_requisite&.dig('description'),
    receipt: operation.deposit_requisite&.dig('receipt'),
    recipient: {
      gateway_id: operation.deposit_requisite&.dig('gateway_id')
    },
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
    pos_link: operation.deposit_requisite&.dig('pos_link'),
  }.compact
end



  public

  def fetch_status(operation)
    response = client.get("\#{BASE_URL}/payments/#{operation.provider_operation_id}", headers: auth_headers)

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
  # TODO: Implement webhook processing according to provider specification
  failure(:unprocessable_entity, 'webhook_not_implemented')
end


public

def check_conditions(operation, request_method)
  base_result = super
  return base_result if base_result.failed?

  if operation.payout_requisite.dig('deal', 'id').blank?
  return failure(:unprocessable_entity, 'id_required')
end
  if operation.payout_requisite.dig('deal', 'id').to_s.length < 36
  return failure(:unprocessable_entity, 'id_too_short')
end
  if operation.payout_requisite.dig('deal', 'id').to_s.length > 50
  return failure(:unprocessable_entity, 'id_too_long')
end

  success
end

# TODO: Webhook signing not detected in specification


# TODO: DigitalSigning signing not detected in specification


private

def encrypt_sensitive_data(payload)
  encrypted_payload = payload.dup
  if encrypted_payload.key?('payment_token')
    encrypted_payload['payment_token'] = encrypt_field(encrypted_payload['payment_token'])
  end
  if encrypted_payload.key?('enforce')
    encrypted_payload['enforce'] = encrypt_field(encrypted_payload['enforce'])
  end
  if encrypted_payload.key?('three_d_secure')
    encrypted_payload['three_d_secure'] = encrypt_field(encrypted_payload['three_d_secure'])
  end
  if encrypted_payload.key?('applied')
    encrypted_payload['applied'] = encrypt_field(encrypted_payload['applied'])
  end
  encrypted_payload
end

def encrypt_field(value)
  # TODO: Implement encryption logic
  value
end

def decrypt_sensitive_data(payload)
  decrypted_payload = payload.dup
  if decrypted_payload.key?('payment_token')
    decrypted_payload['payment_token'] = decrypt_field(decrypted_payload['payment_token'])
  end
  if decrypted_payload.key?('enforce')
    decrypted_payload['enforce'] = decrypt_field(decrypted_payload['enforce'])
  end
  if decrypted_payload.key?('three_d_secure')
    decrypted_payload['three_d_secure'] = decrypt_field(decrypted_payload['three_d_secure'])
  end
  if decrypted_payload.key?('applied')
    decrypted_payload['applied'] = decrypt_field(decrypted_payload['applied'])
  end
  decrypted_payload
end

def decrypt_field(value)
  # TODO: Implement decryption logic
  value
end
end