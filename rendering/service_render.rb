require_relative 'base_render'

class ServiceRender < BaseRender

    def initialize(output_file_path, manifest)
        @output_file_path = output_file_path
        @manifest = manifest
    end

    # @param [ServiceManifest in ../ParsingOpenAPI/service_manifest.rb] data
    def render(data)
        template = ERB.new(
            File.read("templates/new_service.rb.erb")
        )

        result = template.result_with_hash()


        return
    end

    private

    def make_paylod_handler()

    end

end