class TestOperation
  attr_accessor :id, :amount, :currency, :payout_requisite, :provider_operation_id, :external_id, :recipient

  def initialize(attributes = {})
    @id = attributes[:id] || 'op_test_001'
    @external_id = attributes[:external_id] || @id
    @amount = attributes[:amount] || 1500000
    @currency = attributes[:currency] || 'RUB'
    @payout_requisite = attributes[:payout_requisite] || {
      'recipient' => {
        'type' => 'sbp',
        'phone' => '79001234567',
        'bank_code' => '044525225',
        'bank_name' => 'Сбербанк'
      }
    }
    @recipient = @payout_requisite['recipient']  # для проверки operation.recipient
  end

  def update(attrs)
    attrs.each { |k, v| instance_variable_set("@#{k}", v) }
  end
end