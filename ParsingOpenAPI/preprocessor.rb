# frozen_string_literal: true

require "openapi3_parser"
require_relative "service_manifest"

class Preprocessor
  attr_reader :schemas_map
  attr_reader :endpoints_map
  attr_reader :webhooks_map

  HTTP_METHODS = %i[get post put patch delete options head trace].freeze

  def initialize
    @schemas_map = {}
    @endpoints_map = {}
    @webhooks_map = {}

    @document = Openapi3Parser.load_file(
      File.expand_path("../yaml_examples/provider_api.yaml", __dir__)
    )
  end

  def process
    fill_endpoints
    fill_schemas
    fill_webhooks
    print_maps

    provider_name = @document.info['title'].gsub(/\s+/, '_')
    ServiceManifest.new(
      provider_name,
      schemas_map,
      endpoints_map,
      webhooks_map
    )
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

pr = Preprocessor.new
pr.process