class TestOperation
  attr_accessor :id, :amount, :currency, :deposit_requisite, :payout_requisite,
                :provider_operation_id, :external_id, :recipient

  def initialize(attrs = {})
    @id = attrs[:id] || 'op_test_001'
    @external_id = attrs[:external_id] || @id
    @amount = attrs[:amount] || 10000
    @currency = attrs[:currency] || 'RUB'
    @deposit_requisite = attrs[:deposit_requisite] || {
      'payment_method_data' => { 'type' => 'bank_card' },
      'confirmation' => { 'type' => 'redirect', 'return_url' => 'https://example.com/return' },
      'description' => 'Test payment from generator'
    }
    @payout_requisite = attrs[:payout_requisite] || {
  'deal' => { 'id' => '1da5c87d-0984-50e8-a7f3-8de646dd9ec9' }
}
    @provider_operation_id = nil
  end

  def update(attrs)
    attrs.each { |k, v| instance_variable_set("@#{k}", v) }
  end
end