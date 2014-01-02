
module OFlow
  
  # TBD immutable
  class Data

    attr_read :value

    def initialize(value)
      # TBD check type and make sure it is a primitive, array, or hash
      @value = value
    end

    def get(path)
      # TBD 
      nil
    end

    def set(path, value)
      # TBD copy self and return copy with new value set
      nil
    end

    def native()
      # TBD convert to native ruby Hash, Array, and core type
      nil
    end

    private

    def set_no_copy(path, value)
    end

  end # Data

end # OFlow
