# frozen_string_literal: true

class ServiceManifest
  def initialize(provider_name,
                 schemas_map,
                 endpoints_map,
                 webhooks_map,
                 servers)
    @provider_name = provider_name
    @schemas_map = schemas_map
    @endpoints_map = endpoints_map
    @webhooks_map = webhooks_map
    @servers = servers
  end
end
