# heuristics/create_endpoint_heuristic.rb
require_relative 'heuristic'
require_relative '../schema_extractor'


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
        request_schema: SchemaExtractor.request_schema(payout_endpoint.operation)
      }
    end

    deposit_endpoint = find_endpoint_by_keywords(endpoints, ['deposit', 'create'])
    if deposit_endpoint
      result[:deposit_create_endpoint] = {
        path: deposit_endpoint.path,
        method: deposit_endpoint.http_method,
        operation_id: deposit_endpoint.operation.operation_id,
        request_schema: SchemaExtractor.request_schema(endpoint.operation)
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
end