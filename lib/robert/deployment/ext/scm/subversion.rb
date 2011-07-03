require 'yaml'

var[:subversion,:command] = "svn"
var[:subversion,:command,:authentication] = ->{ [var?[:subversion,:username], var?[:subversion,:password]].compact.join(" ") }

defn subversion.head do
  body {
    "HEAD"
  }
end

defn subversion.checkout do
  body { |revision, destination|
    syscmd("#{var[:subversion,:command]} checkout #{var[:subversion,:command,:authentication]} -r#{revision} '#{var[:subversion,:repository]}' '#{destination}'")
  }
end

defn subversion.sync do
  body { |revision, destination|
    syscmd("#{var[:subversion,:command]} update #{var[:subversion,:command,:authentication]} -r#{revision} '#{destination}'")
  }
end

defn subversion.query_revision do
  body { |revision|
    info = syscmd_output("#{var[:subversion,:command]} info #{var[:subversion,:repository]} #{var[:subversion,:command,:authentication]} -r#{revision}")
    yaml = YAML.load(info)
    raise "got unexpected results when trying to query for revision: #{info}" unless Hash === yaml
    [(yaml['Last Changed Rev'] || 0).to_i, (yaml['Revision'] || 0).to_i ].max
  }
end

defn subversion.revision_from_str do
  body { |revision_str|
    revision_str.to_i
  }
end

conf :subversion do
  var[:scm,:name] = "subversion"
  
  act[:scm_head] = subversion.head
  act[:scm_checkout] = subversion.checkout
  act[:scm_sync] = subversion.sync
  act[:scm_query_revision] = subversion.query_revision
  act[:scm_revision_from_str] = subversion.revision_from_str
end

