ext :console_color do
  def colorize(text, color_code)
    "#{color_code}#{text}e[0m"
  end

  def red(text); colorize(text, "e[31m"); end
  def green(text); colorize(text, "e[32m"); end
end

conf :base do
  use :console_color
end
