
module OFlow

  # TBD
  # ship between tasks
  # tracker
  #  tracker has id and keeps track of tasks it's been through, also has timestamps

  # A Box encapsulates data in the system. It provides a wrapper around the data
  # which becomes immutable as it is frozen in transit between Tasks. The Box
  # allows the contents to be modified by replacing the contents with thawed
  # copies of the original data.
  #
  # Boxes are shipped between Tasks. A Tracker can also be attached to a Box to
  # follow it and gather a history of it's movements.
  class Box

    # 
    attr_reader :tracker

    # The contents of the Box.
    attr_reader :contents
    
    # id and data will be frozen and not copied.
    def initialize(value, tracker=nil, frozen=false)
      @tracker = tracker
      value = deep_freeze(value) unless frozen
      @contents = value
    end

    def spawn(value)
      t = nil
      t = @tracker.dup() unless @tracker.nil?
      Box.new(value, t)
    end

    def dup()
      spawn(@contents)
    end

    def receive(location, op)
      return self if @tracker.nil?
      Box.new(@contents, @tracker.receive(location, op), true)
    end

    def set(path, value)
      # TBD need to duplicate all elements on the path that are frozen

      nil
    end

    def get(path)
      # TBD 
      nil
    end

    def to_s()
      "Box{#{@contents}, tracker: #{@tracker}}"
    end
    alias inspect to_s

    # Call when passing to another Task.
    def freeze()
      super
      deep_freeze(@data)
    end

    # Makes a copy of the frozen data to allow modifications.
    def thaw()
      @contents = unfreeze_value(@contensts, true)
    end

    # TBD make these module methods 

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
        # unfreezes the hash itself but not the elements
        value = Hash.new(value)
        value.each { |k, v| value[k] = thaw_value(v, true) } if recurse
      when String
        value = String.new(value)
      end
      value
    end

  end # Box

end # OFlow

