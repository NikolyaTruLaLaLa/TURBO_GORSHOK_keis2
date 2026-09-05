# frozen_string_literal: true

class Heuristic
  def classify(data)
    raise NotImplementedError, "#{self.class} is abstract class" if self.class == Heuristic
  end

  private

  def find_endpoint_by_keywords(endpoints, keywords)
    # Приоритет: сначала ищем по operation_id, затем по пути, затем по тегам
    endpoints.each do |key, endpoint|
      op_id = endpoint.operation.operation_id.downcase
      path = endpoint.path.downcase

      if keywords.any? { |kw| op_id.include?(kw) || path.include?(kw) }
        return endpoint
      end
    end


    nil
  end

  def check_finded_data(finded_data)
    if finded_data.empty?
      puts "Heuristic #{self.class} didn't find some specific data"
    end
  end



end