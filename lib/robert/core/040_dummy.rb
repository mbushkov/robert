defn dummy.dummy do
  body {
  }
end

defn dummy.required do
  body {
    raise "not configured"
  }
end
