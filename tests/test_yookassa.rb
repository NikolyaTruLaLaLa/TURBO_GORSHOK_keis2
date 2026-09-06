#!/usr/bin/env ruby
# test_yookassa.rb
require 'ostruct'
require 'json'
require_relative 'base_service'
require_relative 'yoomoney_api_reference_service'  # путь к вашему сгенерированному классу
require_relative 'test_operation'

class NilClass
  def blank?; true; end
  def present?; false; end
end

class String
  def blank?; strip.empty?; end
  def present?; !blank?; end
end

class Hash
  def blank?; empty?; end
  def present?; !empty?; end
end

class Array
  def blank?; empty?; end
  def present?; !empty?; end
end

# Конфигурация – используйте свои ключи
SHOP_ID = ENV['YOOKASSA_SHOP_ID'] || '1457056'
SECRET_KEY = 'test_fIRk360LBI0KoGyZy-nPanRhkS08tkjjw6atR9gNGc8'

# Устанавливаем BASE_URL (для ЮKassa один URL для теста и продакшена)
ENV['YOOMONEY_API_REFERENCE_BASE_URL'] = 'https://api.yookassa.ru/v3'

credentials = OpenStruct.new(
  shop_id: SHOP_ID,
  secret_key: SECRET_KEY
)

puts "🔐 Использую shopId: #{SHOP_ID}"
puts "🔑 Секретный ключ: #{SECRET_KEY[0..8]}..."

# Инициализируем сервис
service = YoomoneyApiReferenceService.new(credentials)

# Создаём операцию (платёж)
operation = TestOperation.new

# 1. Проверяем условия (check_conditions)
puts "\n📋 Проверка условий..."
result = service.check_conditions(operation, 'deposit')
puts "✅ Check conditions: #{result.inspect}"

# 2. Создаём платёж
puts "\n💰 Создание платежа..."
result = service.create_request(operation, 'deposit')
puts "✅ Create payment: #{result.inspect}"

if result.success?
  if result.data[:confirmation_url]
    puts "\n🔗 Ссылка для оплаты (перейдите в браузере):"
    puts "   #{result.data[:confirmation_url]}"
    puts "\n💳 Используйте тестовую карту:"
    puts "   Номер: 5555 5555 5555 4477"
    puts "   Срок: любая будущая дата"
    puts "   CVV: любой 3 цифры"
  end

  if operation.provider_operation_id
    puts "\n🆔 Provider operation ID: #{operation.provider_operation_id}"

    # 3. Получаем статус (ждём несколько секунд для обработки)
    puts "\n⏳ Ждём 3 секунды для обновления статуса..."
    sleep 3

    status_result = service.fetch_status(operation)
    puts "📊 Статус платежа: #{status_result.inspect}"
  end
else
  puts "\n❌ Ошибка: #{result.error.inspect}"
  if result.error[:message]
    puts "   Сообщение: #{result.error[:message]}"
  end
end

puts "\n✅ Тест завершён."