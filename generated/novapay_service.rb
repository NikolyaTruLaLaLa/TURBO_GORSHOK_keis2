class Provider::NovapayPayoutApiService < BaseService
  BASE_URL = ENV.fetch('NOVAPAY_PAYOUT_API_BASE_URL', 'https://api.sandbox.novapay.example/v1')

  STATUS_MAP = {
  }.freeze

  ERROR_MAP = {
  }.freeze

  def create_request(operation, request_method = 'create')
    payload = build_payout_payload(operation)
    endpoint = '/payouts'

    response = client.post("\#{BASE_URL}\#{endpoint}", json: payload, headers: auth_headers)
    parse_create_response(operation, response, request_method)
  rescue Provider::RateLimitError
    failure(:too_many_requests, 'provider.rate_limit')
  rescue Provider::UnauthorizedError
    failure(:unauthorized, 'provider.invalid_credentials')
  rescue => e
    failure(:internal_error, 'provider.unexpected_error')
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


end