var[:deployment,:link_script,:name] = "link.sh"
var[:deployment,:unlink_script,:name] = "unlink.sh"

defn dist_patch.link_scripts do
  var[:shebang] = "#!/bin/sh"
  
  body {
    link_script = [var[:shebang]]
    (deployment_list.directories + deployment_list.files + deployment_list.links).each do |v|
      prefix = v[2][:sudo] ? "sudo " : ""
      link_script << %Q(#{prefix}mkdir -p '#{File.dirname(v[1])}')
      link_script << %Q(#{prefix}ln -fns "$1"/'#{v[0]}' '#{v[1]}')
    end

    unlink_script = [var[:shebang]]
    (deployment_list.links + deployment_list.files + deployment_list.directories).each do |v|
      prefix = v[2][:sudo] ? "sudo " : ""
      unlink_script << "#{prefix}unlink '#{v[1]}' || :"
    end
    
    open(File.join(revision_build.patched_dist_path, var[:deployment,:link_script,:name]), "w") { |f| f.write link_script.join($/) }
    open(File.join(revision_build.patched_dist_path, var[:deployment,:unlink_script,:name]), "w") { |f| f.write unlink_script.join($/) }
         
    call_next if has_next?
  }
end
