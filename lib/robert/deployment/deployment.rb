$: << "#{File.dirname(__FILE__)}/../.."
Dir["#{File.dirname(__FILE__)}/ext/**/*.rb"].each do |p|
  $top.load(p)
end
