
require 'time'

module OFlow

  class Stamp

    attr_reader :location
    attr_reader :time

    def initialize(location, time=nil)
      @location = location
      @time = (time || Time.now).utc
    end

    def to_s()
      "#{@location}@#{@time.iso8601(9)}"
    end
    alias inspect to_s

  end # Stamp
end # OFlow
