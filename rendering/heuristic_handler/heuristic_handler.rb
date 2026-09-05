class HeuristicHandler
    def handle(finded_data)
        raise NotImplementedError, "#{self.class} is abstract class" if self.class == HeuristicHandler 
    end
end