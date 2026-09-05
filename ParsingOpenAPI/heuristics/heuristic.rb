# frozen_string_literal: true

class Heuristic
  def classify(data)
    raise NotImplementedError, "#{self.class} is abstract class" if self.class == Heuristic 
  end
end
