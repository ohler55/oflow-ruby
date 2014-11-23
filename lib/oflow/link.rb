
module OFlow

  # A Link is the data needed to link one Task with another so that when the
  # ship() method is called the data can be delivered to the destination Task.
  class Link
    
    # Name of the target.
    attr_reader :target_name
    # Name of the target's parent flow.
    attr_reader :flow_name
    # Operation to provide the target.
    attr_reader :op
    # The actual target Task.
    attr_reader :target

    # Creates a new Link. This is called from link() and route() methods on
    # Tasks and Flows.
    # @param flow_name [Symbol|String] parent flow name to find the target task in or nil for this parent
    # @param target_name [Symbol] target Task base name
    # @param op [Symbol] operation to use on the target
    # @param ingress [true|false] indicates the Link is internal
    # @return [Link] new Link
    def initialize(flow_name, target_name, op)
      @target_name = target_name
      @flow_name = flow_name
      @op = op
      @target = nil
    end

    # Delivers a package (Box) to the target.
    # @param box [Box] package to deliver
    def ship(box)
      @target.receive(@op, box)
    end

    # Returns a string representation of the Link.
    def to_s()
      if @flow_name.nil?
        "Link{target_name: #{@target_name}, op: #{op}, target: #{@target}}"
      else
        "Link{target_name: #{@flow_name}:#{@target_name}, op: #{op}, target: #{@target}}"
      end
    end
    alias inspect to_s

  end # Link
end # OFlow
