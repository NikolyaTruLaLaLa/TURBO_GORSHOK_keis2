class BaseRender
  @output_file_path
  @manifest

  def initialize(output_file_path, manifest)
    raise NotImplementedError, "#{self.class} is abstract class" if self.class == BaseRender
  end

  def render(data)
    raise NotImplementedError, "Method #render must be realised #{self.class}"
  end
end
