
module OFlow

  # A Link is the data needed to link one Task with another so that when the
  # ship() method is called the data can be delivered to the destination Task.
  class Link
    
    # Name of the target.
    attr_reader :target_name
    # Operation to provide the target.
    attr_reader :op
    # The actual target Task or Flow.
    attr_reader :target
    # Flag indicating the Link is from a Flow to a Task contained in the Flow.
    attr_reader :ingress

    # Creates a new Link. This is called from link() and route() methods on
    # Tasks and Flows.
    # @param target_name [Symbol] target Task base name
    # @param op [Symbol] operation to use on the target
    # @param ingress [true|false] indicates the Link is internal
    # @return [Link] new Link
    def initialize(target_name, op, ingress=false)
      @target_name = target_name
      @op = op
      @target = nil
      @ingress = ingress
    end

    # Delivers a package (Box) to the target.
    # @param box [Box] package to deliver
    def ship(box)
      @target.receive(@op, box)
    end

    # Returns a string representation of the Link.
    def to_s()
      "Link{ingress: #{@ingress}, target_name: #{@target_name}, op: #{op}, target: #{@target}}"
    end
    alias inspect to_s

  end # Link
end # OFlow
