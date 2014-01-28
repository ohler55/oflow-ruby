
module OFlow

  class Env

    extend HasTasks
    extend HasLog
    extend HasName
    extend HasErrorHandler

    init_name(nil, '')
    init_tasks()

    @error_handler = Task.new(self, :error, ErrorHandler)
    @log = Task.new(self, :log, Log)

  end # Env
end # OFlow
