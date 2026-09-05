class ServiceManifest
  attr_reader :provider_name, :schemas_map, :endpoints_map, :webhooks_map, :servers, :heuristic_data

  def initialize(provider_name,
                 schemas_map,
                 endpoints_map,
                 webhooks_map,
                 servers,
                 heuristic_data)
    @provider_name = provider_name
    @schemas_map = schemas_map
    @endpoints_map = endpoints_map
    @webhooks_map = webhooks_map
    @servers = servers
    @heuristic_data = heuristic_data
  end
end
