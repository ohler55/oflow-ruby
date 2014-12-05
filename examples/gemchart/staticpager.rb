
require 'oflow'

class StaticPager < ::OFlow::Actor
  
  def initialize(task, options={})
    @cache = {}
    set_options(options)
    super
  end

  def perform(op, box)
    path = File.expand_path(File.join(@dir, box.aget([:request, :path])))
    return send_404(box) unless path.start_with?(@dir)
    return send_404(box) if (page = get_page(path)).nil?
    out = {
      request: {
        id: box.aget([:request, :id])
      },
      response: box.aget([:response])
    }
    out_box = ::OFlow::Box.new(out)
    out_box = out_box.aset([:response, :body], page)
    out_box = out_box.aset([:response, :headers, 'Content-Type'], content_type(path))
    task.ship(:reply, out_box)
  end

  def set_options(options)
    @dir = options[:dir]
    @dir = '.' if @dir.nil?
    @dir = File.expand_path(@dir.strip)
  end
  
  def send_404(box)
    out = {
      request: {
        id: box.aget([:request, :id])
      },
      response: box.aget([:response])
    }
    out_box = ::OFlow::Box.new(out)
    out_box = out_box.aset([:response, :status], 404)
    out_box = out_box.aset([:response, :body], "Page not found.")
    task.ship(:reply, out_box)
  end

  def get_page(path)
    page = @cache[path]
    return page unless page.nil?
    begin
      page = File.read(path)
      @cache[path] = page
    rescue
      page = nil
    end
    page
  end

  def content_type(path)
    path.downcase!
    i = path.rindex('.').to_i
    {
      'css' => 'text/css',
      'gif' => 'image/gif',
      'html' => 'text/html',
      'ico' => 'image/x-icon',
      'jpeg' => 'image/jpeg',
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
    }.fetch(path[i+1..-1], 'text/plain')
  end
  
end # StaticPager
