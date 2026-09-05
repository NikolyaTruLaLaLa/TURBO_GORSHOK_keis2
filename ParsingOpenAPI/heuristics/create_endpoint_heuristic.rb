# heuristics/create_endpoint_heuristic.rb
require_relative 'heuristic'

class CreateEndpointHeuristic < Heuristic
  def classify(data)
    endpoints = data[:endpoints_map]
    result = {}

    payout_endpoint = find_endpoint_by_keywords(endpoints, ['payout', 'create'])
    if payout_endpoint
      result[:payout_create_endpoint] = {
        path: payout_endpoint.path,
        method: payout_endpoint.http_method,
        operation_id: payout_endpoint.operation.operation_id,
        request_schema: extract_request_schema(payout_endpoint.operation)
      }
    end

    deposit_endpoint = find_endpoint_by_keywords(endpoints, ['deposit', 'create'])
    if deposit_endpoint
      result[:deposit_create_endpoint] = {
        path: deposit_endpoint.path,
        method: deposit_endpoint.http_method,
        operation_id: deposit_endpoint.operation.operation_id,
        request_schema: extract_request_schema(deposit_endpoint.operation)
      }
    end

    if check_finded_data(result)
      return {
        name: self.class.name,
        finded_data: result
      }
    else
      return nil
    end
  end

  # Возвращает либо имя схемы (если есть ссылка), либо сам объект схемы
  def extract_request_schema(operation)
    request_body = operation.request_body
    return nil unless request_body

    content = request_body.content
    json_content = content['application/json'] || content['application/json; charset=utf-8']
    return nil unless json_content

    schema = json_content.schema
    return nil unless schema

    # Пытаемся получить ссылку
    ref = nil
    if schema.respond_to?(:reference) && schema.reference
      ref = schema.reference
    elsif schema.respond_to?(:source) && schema.source.respond_to?(:reference)
      ref = schema.source.reference
    end

    # Если есть ссылка на компонент, возвращаем имя
    if ref && ref.include?('components/schemas/')
      return ref.split('/').last
    end

    # Иначе возвращаем сам объект схемы (inline)
    schema
  end
end