defn deployment_list.directory do
  body {
    dl = Robert::Deployment::DeploymentList.new
    unless var?[:conditional] && !File.directory?(var[:from])
      dl.directory(var[:from], var[:to])
    end
    dl
  }
end
