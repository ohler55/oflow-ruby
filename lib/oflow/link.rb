
module OFlow

  class Link
    attr_reader :target_name
    attr_reader :op
    attr_reader :target

    def initialize(target_name, op)
      @target_name = target_name
      @op = op
      @target = nil
    end

    def ship(box)
      @target.receive(@op, box)
    end

    def to_s()
      "Link{target_name: #{@target_name}, op: #{op}, target: #{@target}}"
    end
    alias inspect to_s

  end # Link
end # OFlow
