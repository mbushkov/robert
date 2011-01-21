ext :log do
  var[:log,:level,:trace] = LOG_LEVEL_TRACE = 5
  var[:log,:level,:debug] = LOG_LEVEL_DEBUG = 4
  var[:log,:level,:info] = LOG_LEVEL_INFO = 3
  var[:log,:level,:warning] = LOG_LEVEL_WARNING = 2
  var[:log,:level,:error] = LOG_LEVEL_ERROR = 1
  var[:log,:level,:fatal] = LOG_LEVEL_FATAL = 0

  var[:log,:level] = LOG_LEVEL_TRACE

  def log(level, message = nil, &block)
    raise ArgumentError, "either string or block should be provided" if message && block
    if level <= log_level
      puts((respond_to?(:conf_name) ? "[#{conf_name}] " : "") + (message || block.call))
    end
  end

  def logt(message = nil, &block)
    log(LOG_LEVEL_TRACE, message, &block)
  end

  def logd(message = nil, &block)
    log(LOG_LEVEL_DEBUG, message, &block)
  end

  def logi(message = nil, &block)
    log(LOG_LEVEL_INFO, message, &block)
  end

  def logw(message = nil, &block)
    log(LOG_LEVEL_WARNING, message, &block)
  end

  def loge(message = nil, &block)
    log(LOG_LEVEL_ERROR, message, &block)
  end

  def logf(message = nil, &block)
    log(LOG_LEVEL_FATAL, message, &block)
  end

  def log_level
    begin
      $top.rules.eval_rule(rule_ctx + [:cmdline,:args,:log,:level], self)
    rescue RuleStorage::NoSuitableRuleFoundError
      $top.rules.eval_rule(rule_ctx + [:log,:level], self)
    end
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
