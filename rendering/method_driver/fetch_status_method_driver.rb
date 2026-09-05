require_relative 'method_driver'
require 'erb'

class FetchStatusMethodDriver < MethodDriver
  def generate(manifest)
    endpoint = find_status_endpoint(manifest.endpoints_map)
    return '' unless endpoint

    path = endpoint.path
    param_name = extract_path_parameter(path)

    template_path = File.join(__dir__, '../templates/methods/_fetch_status.erb')
    template = ERB.new(File.read(template_path), trim_mode: '-')
    template.result_with_hash(
      endpoint_path: path,
      param_name: param_name
    )
  end

  private

  def find_status_endpoint(endpoints_map)
    endpoints_map.each do |key, endpoint|
      op_id = endpoint.operation.operation_id.downcase
      path = endpoint.path.downcase
      if endpoint.http_method == :get && (op_id.include?('status') || path.include?('status'))
        return endpoint
      end
    end
    nil
  end

  def extract_path_parameter(path)
    match = path.match(/\{([^}]+)\}/)
    match ? match[1] : nil
  end
end
