# Rendering/service_render.rb
require_relative 'base_render'
require_relative 'method_driver/create_request_method_driver'

class ServiceRender < BaseRender
  def initialize(output_filename = 'service.rb')
    @output_filename = output_filename
    @method_drivers = [
      CreateRequestMethodDriver.new,
      # другие драйверы позже
    ]
  end

  def output_filename
    @output_filename
  end

  def render(data)
    @manifest = data
    methods_code = @method_drivers.map { |driver| driver.generate(@manifest) }.join("\n\n")

    provider_name = @manifest.provider_name
    provider_class_name = provider_name.split('_').map(&:capitalize).join
    default_base_url = extract_default_base_url
    status_mapping = extract_status_mapping
    error_mapping = extract_error_mapping

    template_path = File.join(__dir__, 'templates', 'new_service.rb.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result_with_hash(
        provider_name: provider_name,
        provider_class_name: provider_class_name,
        default_base_url: default_base_url,
        status_mapping: status_mapping,
        error_mapping: error_mapping,
        methods_code: methods_code
    )
  end

  private

  def extract_default_base_url
    @manifest.servers['Production'] || @manifest.servers.values.first || ''
  end

  def extract_status_mapping
    # TODO: из эвристики
    {}
  end

  def extract_error_mapping
    # TODO: из эвристики
    {}
  end
end