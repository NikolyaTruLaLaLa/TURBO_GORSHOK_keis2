require_relative 'rendering/service_render'
require_relative 'rendering/writers/writer_file'
require_relative 'ParsingOpenAPI/preprocessor'

class GeneratorPipeline
  attr_reader :renders, :preprocessor, :writer

  def initialize(renders:, file_path:, writer: nil)
    @renders = renders
    @preprocessor = Preprocessor.new(file_path)  
    @writer = writer || WriterFile.new   
  end

  def run(goal_directory)
    puts "Pipeline starts"
    processed_data = @preprocessor.process 

    @renders.each do |render|
      result = render.render(processed_data)
      @writer.write(result, goal_directory, render.output_filename)
    end

    puts "Pipeline is ready. Generated data is in #{goal_directory}"
  end
end