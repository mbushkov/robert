require 'date'
require 'fileutils'

var[:git,:command] = "git"
var[:git,:repository,:local,:command] = ->{ "#{var[:git,:command]} --git-dir='#{var[:git,:repository,:local,:path]}/.git'" }
var[:git,:repository,:branch] = "remotes/origin/HEAD"
var[:rsync,:command] = "rsync"

GitRevision = Struct.new(:time, :revision_hash)
class GitRevision
  def <=>(other)
    time <=> other.time
  end

  def self.from_s(str)
    raise "invalid git revision string: '#{str}'" unless str =~ /^(.+)_(.+)$/
    GitRevision.new(Time.at($1.to_i), $2)
  end
  
  def to_s
    "#{time.to_i}_#{revision_hash}"
  end
end

defn git.sync_local_repo do
  body { |*args|
    git_path = var[:git,:repository,:local,:path]
  
    FileUtils.mkdir_p(git_path)
    Dir.chdir(git_path) do
      if syscmd_status("#{var[:git,:repository,:local,:command]} status") != 0
        syscmd("#{var[:git,:repository,:local,:command]} clone '#{var[:git,:repository]}' .")
      end
      syscmd("#{var[:git,:repository,:local,:command]} fetch")
      syscmd("#{var[:git,:repository,:local,:command]} checkout #{var[:git,:repository,:branch]}")
    end

    call_next(*args) if has_next?
  }
end

defn git.head do
  body {
    "head"
  }
end

defn git.checkout do
  body { |revision, destination|
    Dir.chdir(var[:git,:repository,:local,:path]) do
      syscmd("#{var[:git,:repository,:local,:command]} reset --hard #{revision.revision_hash}")
    end
    syscmd("#{var[:rsync,:command]} -auSx --delete --stats --temp-dir=/tmp #{var[:git,:repository,:local,:path]}/#{var[:git,:repository,:path]}/ #{destination}")
  }
end

defn git.query_revision do
  body { |revision|
    Dir.chdir(var[:git,:repository,:local,:path]) do
      rev_info = syscmd_output("#{var[:git,:repository,:local,:command]} log -n 1 --pretty=format:%at,%H '#{revision}' -- #{var[:git,:repository,:path]}").split(",")      
      GitRevision.new(rev_info[0].to_i, rev_info[1])
    end
  }
end

defn git.revision_from_str do
  body { |revision_str|
    GitRevision.from_s(revision_str)
  }
end

conf :git do
  var[:scm,:name] = "git"
  
  var[:git,:repository,:safename] = ->{ var[:git,:repository].gsub(/:|\//, "-") }
  var[:git,:repository,:local,:path] = ->{ "#{var[:local,:build,:misc]}/#{var[:git,:repository,:safename]}" }
  
  act[:scm_head] = git.head
  act[:scm_checkout] = git.sync_local_repo(git.checkout)
  act[:scm_sync] = git.sync_local_repo(git.checkout)
  act[:scm_query_revision] = git.sync_local_repo(git.query_revision)
  act[:scm_revision_from_str] = git.revision_from_str
end

