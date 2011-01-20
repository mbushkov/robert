require 'aruba/cucumber'
$: << "./lib"

# turn-off spec definitions when evaluating robert files with cucumber
def describe(*args)
end

