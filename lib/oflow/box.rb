
module OFlow

  # A Box encapsulates data in the system. It provides a wrapper around the data
  # which becomes immutable as it is frozen in transit between Tasks. The Box
  # allows the contents to be modified by replacing the contents with thawed
  # copies of the original data.
  #
  # Boxes are shipped between Tasks. A Tracker can also be attached to a Box to
  # follow it and gather a history of it's movements.
  class Box

    # Tracker for the box if there is one.
    attr_reader :tracker

    # The contents of the Box.
    attr_reader :contents
    
    # Create a new Box withe the content provided. The value provided will be
    # frozen to inhibit changes to the value after the Box is created.
    # @param value contents of the Box
    # @param tracker [Tracker] used to track the progress of the Box
    # @param frozen [Boolean] indicates the contents are already frozen. Don't set to true unless the contents are really frozen.
    def initialize(value, tracker=nil, frozen=false)
      @tracker = tracker
      value = deep_freeze(value) unless frozen
      @contents = value
    end
    
    # Creates a copy of a Box with the new value but maintaining the tracker if
    # one was attached.
    # @param value contents of the Box
    def spawn(value)
      t = nil
      t = @tracker.dup() unless @tracker.nil?
      Box.new(value, t)
    end

    # Receives a Box by creating a new Box whose contents is the same as the
    # existing but with an updated tracker.
    # @param location [String] where the Box was received, full name of Task
    # @param op [Symbol] operation that the Box was received under
    # @return [Box] new Box.
    def receive(location, op)
      return self if @tracker.nil?
      Box.new(@contents, @tracker.receive(location, op), true)
    end

    # Sets or adds a value in inside the Box. The Box is changed with the new contents
    # being thawed where necessary.
    # @param path [String] location of element to change or add
    # @param value value for the addition or change
    def set(path, value)
      # TBD need to duplicate all elements on the path that are frozen

      nil
    end

    # Returns the data element described by the path.
    # @param path [String] location of element to return
    # @return the data element.
    def get(path)
      # TBD 
      nil
    end

    # Returns a string representation of the Box and contents.
    def to_s()
      "Box{#{@contents}, tracker: #{@tracker}}"
    end
    alias inspect to_s

    # Called when passing to another Task. It freezes the contents recursively.
    def freeze()
      super
      deep_freeze(@contents)
    end

    # Makes a copy of the frozen contents and the Box to allow modifications.
    # @return [Box] new Box.
    def thaw()
      # Don't freeze the contents.
      Box.new(thaw_value(@contents, true), @tracker, true)
    end

    # TBD make these module methods on a Freezer module 

    def deep_freeze(value)
      value.freeze
      case value
      when Array
        value.each { |v| deep_freeze(v) }
      when Hash
        # hash keys are frozen already
        value.each { |k, v| deep_freeze(v) }
      end
      # Don't freeze other Objects. This leaves an out for special purpose
      # functionality.
      value
    end

    # Make a copy of the value, unfrozen.
    def thaw_value(value, recurse)
      return value unless value.frozen? || recurse
      case value
      when Array
        # thaws the array itself but not the elements
        value = Array.new(value)
        value.map! { |v| thaw_value(v, true) } if recurse
      when Hash
        # thaws the hash itself but not the elements
        value = Hash.new(value)
        value.each { |k, v| value[k] = thaw_value(v, true) } if recurse
      when String
        value = String.new(value)
      end
      value
    end

  end # Box

end # OFlow

