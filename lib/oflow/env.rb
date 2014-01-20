
module OFlow

  class Env

    extend HasTasks
    extend HasLog
    extend HasName
    extend HasErrorHandler

    init_name(nil, '')
    init_tasks()
    
    # Perform additional preparations.
    def self.prepare()
      # TBD make sure log and error_handler are set it env
    end


  end # Env
end # OFlow
