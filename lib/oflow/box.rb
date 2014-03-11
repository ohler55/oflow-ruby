
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
    def initialize(value, tracker=nil)
      @tracker = tracker
      @contents = value
    end
    
    # Receives a Box by creating a new Box whose contents is the same as the
    # existing but with an updated tracker.
    # @param location [String] where the Box was received, full name of Task
    # @param op [Symbol] operation that the Box was received under
    # @return [Box] new Box.
    def receive(location, op)
      return self if @tracker.nil?
      Box.new(@contents, @tracker.receive(location, op))
    end

    # Sets or adds a value in inside the Box. The Box is changed with the new
    # contents being thawed where necessary. A path is a set of element names in
    # the case of a Hash or index numbers in the case of an Array joined with
    # the ':' character as a separator.
    # @param path [String] location of element to change or add. 
    # @param value value for the addition or change
    def set(path, value)
      return aset(nil, value) if path.nil?
      aset(path.split(':'), value)
    end

    # Sets or adds a value in inside the Box where the path is an array of
    # element names or indices. Indices can be Fixnum or Strings.
    # @param path [Array] location of element to change or add. 
    # @param value value for the addition or change
    def aset(path, value)
      Box.new(_aset(path, @contents, value), @tracker)
    end

    # Returns the data element described by the path. A path is a set of element
    # names in the case of a Hash or index numbers in the case of an Array
    # joined with the ':' character as a separator.
    # @param path [String] location of element to return
    # @return the data element.
    def get(path)
      return @contents if path.nil?
      aget(path.split(':'))
    end

    # Returns the data element described by the path which is an array of
    # element names or indices. Indices can be Fixnum or Strings.
    # @param path [Array] location of element to return
    # @return the data element.
    def aget(path)
      _aget(path, @contents)
    end

    # Returns a string representation of the Box and contents.
    def to_s()
      if @tracker.nil?
        "Box{#{@contents}}"
      else
        "Box{#{@contents}, tracker: #{@tracker}}"
      end
    end
    alias inspect to_s

    # Called when passing to another Task. It freezes the contents recursively.
    def freeze()
      deep_freeze(@contents)
      super
    end

    # Makes a copy of the frozen contents and the Box to allow modifications.
    # @return [Box] new Box.
    def thaw()
      # Don't freeze the contents.
      Box.new(thaw_value(@contents, true), @tracker)
    end

    # TBD make these module methods on a Freezer module 

    def deep_freeze(value)
      case value
      when Array
        value.each { |v| deep_freeze(v) }
      when Hash
        # hash keys are frozen already
        value.each { |k, v| deep_freeze(v) }
      end
      # Don't freeze other Objects. This leaves an out for special purpose
      # functionality.
      value.freeze
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
        orig = value
        value = {}
        if recurse
          orig.each { |k, v| value[k] = thaw_value(v, true) }
        else
          orig.each { |k, v| value[k] = v }
        end
      when String
        value = String.new(value)
      end
      value
    end

    private

    def _aset(path, value, rv)
      return rv if path.nil? || path.empty?
      p = path[0]
      case value
      when Array
        value = Array.new(value) if value.frozen?
        i = p.to_i
        value[p.to_i] = _aset(path[1..-1], value[i], rv)
      when Hash
        if value.frozen?
          orig = value
          value = {}
          orig.each { |k, v| value[k] = v }
        end
        if value.has_key?(p)
          value[p] = _aset(path[1..-1], value[p], rv)
        else
          ps = p.to_sym
          value[ps] = _aset(path[1..-1], value[ps], rv)
        end
      when NilClass
        if /^\d+$/.match(p).nil?
          ps = p.to_sym
          value = {}
          value[ps] = _aset(path[1..-1], nil, rv)
        else
          i = p.to_i
          value = []
          value[i] = _aset(path[1..-1], nil, rv)
        end
      else
        raise FrozenError.new(p, value)
      end
      value
    end

    def _aget(path, value)
      return value if path.nil? || path.empty? || value.nil?
      p = path[0]
      case value
      when Array
        begin
          _aget(path[1..-1], value[p.to_i])
        rescue
          nil
        end
      when Hash
        v = value[p] || value[p.to_sym]
        _aget(path[1..-1], v)
      else
        if value.respond_to?(p.to_sym)
          _aget(path[1..-1], value.send(p))
        else
          nil
        end
      end
    end

  end # Box

end # OFlow

