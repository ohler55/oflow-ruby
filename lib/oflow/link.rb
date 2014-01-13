
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

  end # Link
end # OFlow
