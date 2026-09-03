require "openapi3_parser"

class DFS_Module
  HTTP_METHODS = %w[
    get
    post
    put
    delete
    patch
    head
    options
  ].freeze

  attr_reader :schemas_map
  attr_reader :endpoints_map
  attr_reader :webhooks_map

  def initialize
    @document = Openapi3Parser.load_file("provider_api.yaml")

    @schemas_map = {}
    @endpoints_map = {}
    @webhooks_map = {}
  end

  def fill_maps
    fill_endpoints
    fill_webhooks
    fill_schemas

    print_maps
  end

  private

  def fill_endpoints
    @document.paths.each do |path, path_item|
      HTTP_METHODS.each do |method|
        operation = path_item.public_send(method)

        next unless operation

        key = "#{method.upcase} #{path}"

        @endpoints_map[key] = operation
      end
    end
  end

  def fill_webhooks
    @endpoints_map.each do |key, operation|
      next unless operation.tags&.include?("Webhooks")

      name = operation.operation_id || key

      @webhooks_map[name] = operation
    end
  end

  def fill_schemas
    @document.components.schemas.each do |name, schema|
      @schemas_map[name] = schema
    end
  end

  def print_maps
    puts "\n=== Схемы(#{@schemas_map.size}) ==="
    @schemas_map.each do |key, value|
      puts "KEY: #{key}"
      pp value
      puts
    end

    puts "\n=== Эндпоинты(#{@endpoints_map.size}) ==="
    @endpoints_map.each do |key, value|
      puts "KEY: #{key}"
      pp value
      puts
    end

    puts "\n=== Вебхуки(#{@webhooks_map.size}) ==="
    @webhooks_map.each do |key, value|
      puts "KEY: #{key}"
      pp value
      puts
    end
  end
end