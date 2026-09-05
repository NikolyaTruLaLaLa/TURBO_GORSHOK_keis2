require_relative 'method_driver'
require_relative '../heuristic_handler/create_endpoint_heuristic_handler'

class CreateRequestMethodDriver < MethodDriver
  def generate(manifest)
    handler = CreateEndpointHeuristicHandler.new
    handler.handle(manifest)   # передаём объект ServiceManifest
  end
end