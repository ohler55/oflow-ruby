
require 'time'

module OFlow

  class Stamp

    attr_reader :location
    attr_reader :op
    attr_reader :time

    def initialize(location, op=nil, time=nil)
      @location = location
      @op = op
      @time = (time || Time.now).utc
    end

    def where()
      "#{@location}-#{@op}"
    end

    def to_s()
      "#{@location}-#{@op}@#{@time.iso8601(9)}"
    end
    alias inspect to_s

  end # Stamp
end # OFlow
