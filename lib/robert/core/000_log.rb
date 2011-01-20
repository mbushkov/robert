ext :log do
  var[:log,:level,:trace] = 5
  var[:log,:level,:debug] = 4
  var[:log,:level,:info] = 3
  var[:log,:level,:warning] = 2
  var[:log,:level,:error] = 1
  var[:log,:level,:fatal] = 0

  var(:log,:level) { var[:log,:level,:trace] }

  def log(level, message = nil, &block)
    raise ArgumentError, "either string or block should be provided" if message && block
    if level <= log_level
      puts((respond_to?(:conf_name) ? "[#{conf_name}] " : "") + (message || block.call))
    end
  end

  def logt(message = nil, &block)
    log(var[:log,:level,:trace], message, &block)
  end

  def logd(message = nil, &block)
    log(var[:log,:level,:debug], message, &block)
  end

  def logi(message = nil, &block)
    log(var[:log,:level,:info], message, &block)
  end

  def logw(message = nil, &block)
    log(var[:log,:level,:warning], message, &block)
  end

  def loge(message = nil, &block)
    log(var[:log,:level,:error], message, &block)
  end

  def logf(message = nil, &block)
    log(var[:log,:level,:fatal], message, &block)
  end

  def log_level
    var[:log,:level]
  end
end

conf :base do
  use :log
end

defn console.print do
  body {
    puts var[:message]
  }
end
