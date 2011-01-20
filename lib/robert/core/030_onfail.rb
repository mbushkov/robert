defn onfail.continue do
  body do |*args|
    begin
      call_next(*args)
    rescue => e
      loge "#{e} happened"
    end
  end
end

defn onfail.tryagain do
  var(:max_tries) { 1024 }
  var(:pause) { 0 }

  body do |*args|
    tries = 0
    begin
      call_next(*args)
    rescue => e
      tries += 1
      if tries < var[:max_tries]
        loge "#{e} happened #{tries} times, sleeping for #{var[:pause]}s, then retrying"
        sleep(var[:pause])
        retry
      else
        logf "#{e} happened #{tries} times, exceeding maximum tries limit (#{var[:max_tries]}), failing"
        raise
      end
    end
  end
end
