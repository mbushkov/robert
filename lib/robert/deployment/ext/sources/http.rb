require 'open-uri'

defn sources.http do
  var(:to) { File.basename(var[:from]) }
  
  body {
    brev = build_repository[revision]
    brev.setup!

    logd "fetching #{var[:from]} to #{var[:to]}"
    open var[:from] do |fin|
      open("#{brev.src_path}/#{var[:to]}", "w") do |fout|
        fout.write(fin.read)
      end
    end    
  }

end
