
require 'socket'

module OFlow

  class Tracker
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

    attr_reader :id
    attr_reader :track

    def initialize(location)
      # if an internal new then return leaving fields unset
      return if location.nil?

      nano = (Time.now.to_f * 1000000000.0).to_i
      @@nano_mutex.synchronize do
        while nano <= @@last_nano
          nano += 1
        end
        @@last_nano = nano
      end
      @id = "#{@@machine}.#{@@pid}.#{nano}"
      @track = [Stamp.new(location)]
      @track.freeze
    end

    def receive(location, op)
      t = Tracker.new(nil)
      t.id = @id
      t.track = Array.new(@track) << Stamp.new(location, op)
      t
    end

    def to_s()
      "Tracker{#{@id}, track: #{@track}}"
    end
    alias inspect to_s

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
      t = Tracker.new(nil)
      t.id = @id
      t.track = comb
      t
    end

    protected

    def id=(i)
      @id = i
    end

    def track=(t)
      @track = t
    end

    def dup()
      t = Tracker.new()
      t.id = @id
    end

  end # Tracker
end # OFlow
