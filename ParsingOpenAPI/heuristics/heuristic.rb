# frozen_string_literal: true

class Heuristic
  def classify(data)
    raise NotImplementedError, "#{self.class} is abstract class" if self.class == Heuristic 
  end

  private

  def find_endpoint_by_keywords(endpoints, keywords)
    endpoints.each do |key, endpoint|
      op_id = endpoint.operation.operation_id.downcase
      path = endpoint.path.downcase
      # Все ключевые слова должны присутствовать либо в op_id, либо в path
      if keywords.all? { |kw| op_id.include?(kw) || path.include?(kw) }
        return endpoint
      end
    end
    nil
  end

  def check_finded_data(finded_data)
    if finded_data.empty?
      puts "Heuristic #{self.class} didn't find some specific data"
      return false
    end

    return true
  end



end
