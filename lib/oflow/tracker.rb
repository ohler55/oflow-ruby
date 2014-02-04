
require 'socket'

module OFlow

  # A Tracker is used to track data through the system. They are attached to
  # Boxes and are updated when they are received by Flows and Tasks.
  class Tracker
    # Gets the machine address. This is used for generating unique identifiers
    # for the Tracker instances.
    def self.get_machine()
      machine = "unknown"
      Socket.ip_address_list.each do |addr|
        next unless addr.ip?
        next if addr.ipv6_linklocal?
        next if addr.ipv4_loopback? || addr.ipv6_loopback?
        next if addr.ipv4_multicast? || addr.ipv6_multicast?
        machine = addr.ip_address
        break
      end
      machine
    end

    @@machine = self.get_machine()
    @@pid = Process.pid
    @@last_nano = 0
    @@nano_mutex = Mutex.new()

    # The identifier of the Tracker.
    attr_reader :id
    # The Stamps that were placed in the Tracker as it is received.
    attr_reader :track

    def self.create(location, op=nil)
      t = Tracker.new(gen_id(), [Stamp.new(location, op).freeze()])
      t.track.freeze()
      t.freeze()
    end

    # Returns an updated instance with a Stamp for the location, operation, and
    # current time.
    # @param location [String] full name of Task where the Tracker was received
    # @param op [Symbol] operation that caused the Stamp to be created
    # @return [Tracker] updated Tracker
    def receive(location, op)
      t = Tracker.new(@id, Array.new(@track) << Stamp.new(location, op).freeze())
      t.track.freeze()
      t.freeze()
    end

    # Returns a String representation of the Tracker.
    def to_s()
      "Tracker{#{@id}, track: #{@track}}"
    end
    alias inspect to_s

    # When a package is split and travels on more than one route the Tracker can
    # be merged with this method. The returned Tracker contains both tracks.
    # @param t2 [Tracker] other Tracker
    # @return [Tracker] merged Tracker
    def merge(t2)
      raise Exception.new("Can not merge #{t2.id} into #{@id}. Different IDs.") if t2.id != @id
      comb = []
      s2 = t2.track.size
      for i in 0..@track.size
        break if s2 <= i
        unless @track[i] == t2.track[i]
          if @track[-1].location == t2.track[-1].location
            comb << [@track[i..-2], t2.track[i..-2]]
            comb << @track[-1]
          else
            comb << [@track[i..-1], t2.track[i..-1]]
          end
          break
        end
        comb << @track[i]
      end
      comb.freeze
      Tracker.new(@id, comb)
    end

    private

    def self.gen_id()
      nano = (Time.now.to_f * 1000000000.0).to_i
      @@nano_mutex.synchronize do
        while nano <= @@last_nano
          nano += 1
        end
        @@last_nano = nano
      end
      "#{@@machine}.#{@@pid}.#{nano}"
    end

    def initialize(id, track)
      @id = id
      @track = track
    end

    def id=(i)
      @id = i
    end

    def track=(t)
      @track = t
    end

  end # Tracker
end # OFlow
