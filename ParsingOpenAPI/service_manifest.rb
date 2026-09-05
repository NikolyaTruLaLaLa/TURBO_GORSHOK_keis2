# frozen_string_literal: true

class ServiceManifest
  def initialize(provider_name,
                 schemas_map,
                 endpoints_map,
                 webhooks_map)

    @provider_name = provider_name
    #@servers = 
    @schemas_map = schemas_map
    @endpoints_map = endpoints_map
    @webhooks_map = webhooks_map
  end
end
