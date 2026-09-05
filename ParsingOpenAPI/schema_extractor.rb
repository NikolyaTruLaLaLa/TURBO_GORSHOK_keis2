# lib/schema_extractor.rb
module SchemaExtractor
  def self.request_schema(operation)
    request_body = operation.request_body
    return nil unless request_body

    content = request_body.content
    json_content = content['application/json'] || content['application/json; charset=utf-8']
    return nil unless json_content

    extract_schema_with_ref(json_content.schema)
  end

  def self.response_schema(operation, status = '200')
    responses = operation.responses
    response = responses[status] || responses['default']
    return nil unless response

    content = response.content
    json_content = content['application/json'] || content['application/json; charset=utf-8']
    return nil unless json_content

    extract_schema_with_ref(json_content.schema)
  end

  private

  def self.extract_schema_with_ref(schema)
    return nil unless schema

    # Пытаемся получить ссылку на компонент
    ref = nil
    if schema.respond_to?(:reference) && schema.reference
      ref = schema.reference
    elsif schema.respond_to?(:source) && schema.source.respond_to?(:reference)
      ref = schema.source.reference
    end

    if ref && ref.include?('components/schemas/')
      return ref.split('/').last  # возвращаем имя схемы
    end

    schema  # inline-схема – возвращаем объект
  end
end