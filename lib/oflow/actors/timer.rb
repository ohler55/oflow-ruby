
require 'logger'

module OFlow

  class Timer < Actor

    # When to trigger the first event. nil means start now.
    attr_reader :start
    # The stop time. If nil then there is not stopping unless the repeat limit
    # kicks in.
    attr_reader :stop
    # How long to wait between each trigger. nil indicates as fast as possible,
    attr_reader :period
    # How many time to repeat before stopping. nil mean go forever.
    attr_reader :repeat

    def initialize(task, options={})
      set_options(options)
      super
      
      # TBD start or start sleeping
    end

    def perform(task, op, box)
      # TBD ops
      #   change an option
      #   stop
      #   trigger
      
      # ship to self or call receive on task
      
    end

    def set_options(options)
      @start = options[:start]
      @stop = options[:stop]
      @period = options[:period]
      @repeat = options[:repeat]
      # TBD check values
    end

  end # Timer
end # OFlow
