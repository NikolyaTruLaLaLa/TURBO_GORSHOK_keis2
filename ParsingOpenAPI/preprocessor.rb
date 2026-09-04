# frozen_string_literal: true

require "openapi3_parser"
require_relative "service_manifest"

class Preprocessor
  Endpoint = Data.define(
    :path,
    :http_method,
    :operation
  )

  attr_reader :schemas_map
  attr_reader :endpoints_map
  attr_reader :webhooks_map
  attr_reader :servers_map

  HTTP_METHODS = %i[
    get
    post
    put
    patch
    delete
    options
    head
    trace
  ].freeze

  def initialize(spec_path)
    @schemas_map = {}
    @endpoints_map = {}
    @webhooks_map = {}
    @servers_map = {}

    @document = Openapi3Parser.load_file(spec_path)
  end

  def process
    fill_endpoints
    fill_schemas
    fill_webhooks
    fill_servers

    print_maps

    provider_name = @document.info["title"].gsub(/\s+/, "_")
    ServiceManifest.new(
      provider_name,
      schemas_map,
      endpoints_map,
      webhooks_map,
      servers_map
    )
  end

  private

  def fill_servers
    @servers_map = @document.servers.each_with_object({}) do |server, servers|
      servers[server.description] = server.url
    end
  end

  def fill_endpoints
    @document.paths.each do |path, path_item|
      HTTP_METHODS.each do |method|
        operation = path_item.public_send(method)

        next unless operation

        key = "#{method.upcase} #{path}"

        @endpoints_map[key] = Endpoint.new(
          path,
          method,
          operation
        )
      end
    end
  end

  def fill_webhooks
    @endpoints_map.each do |key, endpoint|
      next unless endpoint.operation.tags&.include?("Webhooks")

      name = endpoint.operation.operation_id || key

      @webhooks_map[name] = endpoint
    end
  end

  def fill_schemas
    @document.components.schemas.each do |name, schema|
      @schemas_map[name] = schema
    end
  end

  def print_maps
    puts "\n=== Схемы(#{@schemas_map.size}) ==="

    @schemas_map.each do |key, schema|
      puts "KEY: #{key}"
      pp schema
      puts
    end

    puts "\n=== Эндпоинты(#{@endpoints_map.size}) ==="

    @endpoints_map.each do |key, endpoint|
      puts "KEY: #{key}"
      puts "PATH: #{endpoint.path}"
      puts "METHOD: #{endpoint.http_method}"
      puts "OPERATION ID: #{endpoint.operation.operation_id}"
      puts
    end

    puts "\n=== Вебхуки(#{@webhooks_map.size}) ==="

    @webhooks_map.each do |key, endpoint|
      puts "KEY: #{key}"
      puts "PATH: #{endpoint.path}"
      puts "METHOD: #{endpoint.http_method}"
      puts "OPERATION ID: #{endpoint.operation.operation_id}"
      puts
    end

    puts "\n=== Сервера(#{@servers_map.size}) ==="
    @servers_map.each do |key, value|
      puts "KEY: #{key}"
      puts "PATH: #{value}"
      puts
    end
  end

end

pr = Preprocessor.new(
  File.expand_path("../yaml_examples/provider_api.yaml", __dir__)
)

pr.process
