# frozen_string_literal: true

require_relative "base_render"
require "erb"

class DocumentationRender < BaseRender
  DEFAULT_TEMPLATE_PATH = File.join(__dir__, "templates", "documentation.erb")

  def initialize(output_filename = "INTEGRATION.md")
    @output_filename = output_filename
  end

  def output_filename
    @output_filename
  end


  def render(data)
    @manifest = data
    @provider_name = @manifest.provider_name
    @endpoints = @manifest.endpoints_map
    @schemas = @manifest.schemas_map
    @servers = @manifest.servers
    @heuristics = @manifest.heuristic_data
    @security_schemes = @manifest.security_schemes_map

    template_content = File.read(DEFAULT_TEMPLATE_PATH)
    template = ERB.new(template_content, trim_mode: "-")

    auth_section = build_auth_section
    methods_table = build_methods_table
    status_mapping = build_status_mapping
    error_mapping = build_error_mapping
    gateway_config = build_gateway_config
    webhook_signature = build_webhook_signature

    locals = {
      provider_name: @provider_name,
      auth_section: auth_section,
      methods_table: methods_table,
      status_mapping: status_mapping,
      error_mapping: error_mapping,
      gateway_config: gateway_config,
      webhook_signature: webhook_signature
    }

    template.result_with_hash(locals)
  end

  private

  def build_auth_section
    return "Авторизация не требуется." if @security_schemes.nil? || @security_schemes.empty?

    sections = @security_schemes.map do |name, scheme|
      build_security_scheme(name, scheme)
    end

    sections.join("\n\n")
  end

  def build_security_scheme(name, scheme)
    lines = []
    lines << "### #{name}"
    lines << "- Тип: #{scheme[:type]}" if scheme[:type]

    case scheme[:type]
    when "apiKey"
      lines << "- Параметр: `#{scheme[:name]}` (in: #{scheme[:in]})" if scheme[:name]
    when "http"
      lines << "- Схема: #{scheme[:scheme]}" if scheme[:scheme]
      lines << "- Bearer format: #{scheme[:bearerFormat]}" if scheme[:bearerFormat]
    when "oauth2"
      if scheme[:flows]
        flows = scheme[:flows].keys.join(", ")
        lines << "- Потоки: #{flows}"
      end
    when "openIdConnect"
      lines << "- URL: #{scheme[:openIdConnectUrl]}" if scheme[:openIdConnectUrl]
    end

    lines << "- Хранение: `providers.credentials` (encrypted)"
    lines.join("\n")
  end

  def build_methods_table
    rows = []
    @endpoints.each_value do |endpoint|
      op = endpoint.operation
      next unless op

      purpose = op.summary || op.description || "—"
      idempotent = if endpoint.http_method == :post && !endpoint.path.include?('{')
                     "Idempotency-Key header"
                   else
                     "—"
                   end
      method_name = op.operation_id || "#{endpoint.http_method.upcase}_#{endpoint.path.gsub(/[\/{}]/, '_')}"

      rows << [method_name, endpoint.path, purpose, idempotent]
    end
    return "Нет доступных методов" if rows.empty?

    table = "| Метод | Endpoint | Назначение | Idempotency |\n"
    table += "|-------|----------|------------|-------------|\n"
    rows.each do |row|
      table += "| #{row[0]} | #{row[1]} | #{row[2]} | #{row[3]} |\n"
    end
    table
  end

  def build_status_mapping
    status_info = @heuristics.find { |h| h.key?(:status_mapping) } || {}
    mapping = status_info[:status_mapping] || default_status_mapping
    return "Не указан" if mapping.nil? || mapping.empty?

    table = "| Provider | Space Payments |\n"
    table += "|----------|----------------|\n"
    mapping.each do |provider_status, space_status|
      table += "| #{provider_status} | #{space_status} |\n"
    end
    table
  end

  def default_status_mapping
    {
      "pending" => "in_progress",
      "processing" => "in_progress",
      "completed" => "approved",
      "failed" => "rejected",
      "cancelled" => "rejected"
    }
  end

  def build_error_mapping
    error_map = {}
    @endpoints.each_value do |endpoint|
      op = endpoint.operation
      next unless op && op.responses

      op.responses.each do |status, response|
        next unless status.to_s.start_with?("4", "5")
        error_code = extract_error_code(response)
        next unless error_code

        action = determine_error_action(status, error_code)
        error_map[status] = { code: error_code, action: action }
      end
    end
    return "Не указана" if error_map.empty?

    table = "| HTTP | Provider code | Действие |\n"
    table += "|------|---------------|----------|\n"
    error_map.each do |http_status, info|
      table += "| #{http_status} | #{info[:code]} | #{info[:action]} |\n"
    end
    table
  end

  def extract_error_code(response)
    return nil unless response.content && response.content["application/json"]
    schema = response.content["application/json"].schema
    return nil unless schema

    if schema.properties && schema.properties["code"]
      "error_code"
    elsif schema.properties && schema.properties["error"] && schema.properties["error"].properties
      "error.code"
    else
      "unknown"
    end
  end

  def determine_error_action(http_status, _error_code)
    case http_status.to_i
    when 400, 422 then "reject"
    when 401 then "alert ops, block provider"
    when 402 then "retry later"
    when 429 then "retry with backoff"
    when 500 then "retry, alert ops"
    else "retry"
    end
  end

  def build_gateway_config
    endpoint_key = "POST /payouts"
    endpoint = @endpoints[endpoint_key]
    return "Не указана" unless endpoint

    operation = endpoint.operation
    return "Не указана" unless operation && operation.operation_id == 'createPayout'

    schema = extract_request_schema(operation)
    return "Не указана" unless schema

    properties = schema.properties
    return "Не указана" unless properties

    recipient_prop = properties['recipient']
    return "Не указана" unless recipient_prop

    recipient_properties = recipient_prop.properties
    return "Не указана" unless recipient_properties

    # Проверяем тип получателя
    type_prop = recipient_properties['type']
    return "Не указана" unless type_prop && type_prop.enum&.include?('sbp')

    # Проверяем валюту
    currency_prop = properties['currency']
    return "Не указана" unless currency_prop && currency_prop.enum&.include?('RUB')

    external_method = 'sbp_payout'
    gateway = 'RUB_SBP_WITHDRAW'

    "{ \"external_method\": \"#{external_method}\", \"gateway\": \"#{gateway}\" }"
  end

  def extract_request_schema(operation)
    return nil unless operation.request_body
    content = operation.request_body.content
    return nil unless content && content['application/json']
    content['application/json'].schema
  end

  def build_webhook_signature
    wh_heuristic = @heuristics.find { |h| h[:name] == 'WebhookSigningHeuristic' }
    if wh_heuristic && wh_heuristic[:finded_data] && !wh_heuristic[:finded_data].empty?
      first_endpoint_key, info = wh_heuristic[:finded_data].first
      algorithm = info[:algorithm] || 'Неизвестный алгоритм'
      header = info[:header] || 'заголовок не указан'
      return "#{algorithm}(body, callback_secret) → hex → #{header}"
    end

    if @manifest.webhooks_map && !@manifest.webhooks_map.empty?
      webhook_paths = @manifest.webhooks_map.keys.join(', ')
      return "Указаны вебхуки (#{webhook_paths}), но алгоритм подписи не определён в спецификации."
    end

    "Не указана"
  end
end