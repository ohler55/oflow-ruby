
module OFlow
  module Test
    
    class Action
      attr_reader :dest
      attr_reader :box

      def initialize(dest, box)
        @dest = dest
        @box = box
      end

      def to_s()
        "#{@dest}: #{box.contents}"
      end
      alias inspect to_s

    end # Action
  end # Test
end # OFlow
