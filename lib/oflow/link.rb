
module OFlow

  class Link
    attr_reader :target_name
    attr_reader :op
    attr_reader :target
    attr_reader :ingress

    def initialize(target_name, op, ingress=false)
      @target_name = target_name
      @op = op
      @target = nil
      @ingress = ingress
    end

    def ship(box)
      @target.receive(@op, box)
    end

    def to_s()
      "Link{ingress: #{@ingress}, target_name: #{@target_name}, op: #{op}, target: #{@target}}"
    end
    alias inspect to_s

  end # Link
end # OFlow
