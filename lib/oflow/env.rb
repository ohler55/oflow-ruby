
module OFlow

  class Env

    extend HasTasks
    extend HasLog
    extend HasName
    extend HasErrorHandler

    init_name(nil, '')
    init_tasks()

    def self._clear()
      @error_handler = Task.new(self, :error, Actors::ErrorHandler)
      @log = Task.new(self, :log, Actors::Log)
    end

    _clear()

    def self.describe(indent=0)
      i = ' ' * indent
      lines = ["#{i}#{self} {"]
      @tasks.each_value { |t|
        lines << t.describe(indent + 2)
      }
      lines << i + "}"
      lines.join("\n")
    end

  end # Env
end # OFlow
