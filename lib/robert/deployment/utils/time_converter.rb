module Robert
module TimeConverter
  
  def time_to_int(time)
    Integer(time_to_str(time))
  end
  module_function :time_to_int
  
  def int_to_time(int)
    str_to_time(int.to_s)
  end
  module_function :int_to_time
  
  def time_to_str(time)
    time.strftime("%Y%m%d%H%M%S")
  end
  module_function :time_to_str
  
  def str_to_time(str)
    raise RuntimeError, "invalid time string" unless str =~ /(....)(..)(..)(..)(..)(..)/
    Time.mktime($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, 0)
  end
  module_function :str_to_time
    
end
end
