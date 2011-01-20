defn deployment_list.empty do
  body {
    Robert::Deployment::DeploymentList.new
  }
end
