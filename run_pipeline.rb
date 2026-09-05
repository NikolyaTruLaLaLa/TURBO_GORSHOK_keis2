require_relative 'generator_pipeline'
require_relative 'rendering/service_render'

renders = [
  ServiceRender.new('novapay_service.rb')
]

pipeline = GeneratorPipeline.new(renders: renders, file_path: 'yaml_examples/provider_api.yaml')
pipeline.run('generated')
