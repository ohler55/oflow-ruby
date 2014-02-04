
require 'time'

module OFlow

  # Information used to identify a location and time that a Box was
  # received. Stamps are placed in Trackers.
  class Stamp

    # Full name of Task that created the Stamp in a Tracker.
    attr_reader :location
    # Operation that caused the Stamp to be created.
    attr_reader :op
    # The time the Stamp was created.
    attr_reader :time

    # Create a new Stamp.
    # @param location [String] full name of Task that created the Stamp in a Tracker
    # @param op [Symbol] operation that caused the Stamp to be created
    # @param time [Time] time the Stamp was created
    def initialize(location, op=nil, time=nil)
      @location = location
      @op = op
      @time = (time || Time.now).utc
    end

    # Returns a string composed of the location and operation.
    def where()
      "#{@location}-#{@op}"
    end

    # Returns a String representation of the Stamp.
    def to_s()
      "#{@location}-#{@op}@#{@time.iso8601(9)}"
    end
    alias inspect to_s

  end # Stamp
end # OFlow
