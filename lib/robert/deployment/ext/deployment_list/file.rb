defn deployment_list.file do
  body {
    dl = Robert::Deployment::DeploymentList.new
    unless var?[:conditional] && !File.file?(var[:from])
      dl.file(var[:from], var[:to])
    end
    dl
  }
end
