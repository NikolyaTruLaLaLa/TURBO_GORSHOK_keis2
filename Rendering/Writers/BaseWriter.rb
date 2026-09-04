class BaseWriter
    def initialize
        raise NotImplementedError, "#{self.class} is abstract class" if self.class == BaseRender
    end

    def write(filename, content)
        raise NotImplementedError, "Method #render must be realised #{self.class}"
    end
end