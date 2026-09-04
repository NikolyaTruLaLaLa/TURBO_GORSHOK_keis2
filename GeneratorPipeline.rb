require_relative 'Rendering/BaseRender'
require_relative 'Rendering/Writers/BaseWriter'
require_relative 'ParsingOpenAPI/Preprocessor'


class GeneratorPipeline
    attr_reader :renders, :preprocessor, :writer

    def initialize(renders:, preprocessor_options: {}, writer: nil)
        @renders = renders
        @preprocessor = Preprocessor.new(preprocessor_options)
        @writer = writer || Writer.new
    end

    def run(input_open_api_path, goal_directory)
        puts "Pipeline starts"

        processed_data = preprocessor.process(input_open_api_path)

        renders.each do |render|
           result = render.render(processed_data) 
           writer.write(result)
        end

        puts "Pipeline is ready. Generated data is in #{goal_directory}"
    end

end
