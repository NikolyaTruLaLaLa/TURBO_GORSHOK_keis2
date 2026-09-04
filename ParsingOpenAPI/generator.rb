require "erb"
require_relative "dfs_module"

class Generator
  def initialize(dfs)
    @dfs = dfs
  end

  def generate
    generate_schemas
    ##generate_endpoints
    ##generate_webhooks
  end

  private

  def generate_schemas
    @dfs.schemas_map.each do |name, schema|
      template = ERB.new(
        File.read("templates/schema.rb.erb")
      )

      class_name = name
      properties = schema.properties || {}

      result = template.result_with_hash(
        class_name: class_name,
        properties: properties
      )

      File.write(
        "generated/schemas/#{name}.rb",
        result
      )
    end
  end
end

dfs = DFS_Module.new
dfs.fill_maps

generator = Generator.new(dfs)
generator.generate