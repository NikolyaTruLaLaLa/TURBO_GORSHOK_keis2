require_relative 'generator_pipeline'
require_relative 'rendering/service_render'
require_relative 'rendering/fixtures_render'
require_relative 'rendering/documentation_render'

renders = [
  ServiceRender.new('novapay_service.rb'),
  FixturesRender.new('fixtures.json'),
  DocumentationRender.new('integration.md'),
]

pipeline = GeneratorPipeline.new(renders: renders, file_path: 'yaml_examples/provider_api.yaml')
pipeline.run('generated')
