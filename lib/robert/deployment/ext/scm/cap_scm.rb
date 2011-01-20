require 'capistrano/recipes/deploy/scm/base'

[:accurev, :bzr, :cvs, :darcs, :git, :mercurial, :perforce, :subversion, :none].each do |scm_type|
  defn "scm.#{scm_type}" do
    body {
      require "capistrano/recipes/deploy/scm/#{scm_type}"
      scm_const = scm_type.to_s.capitalize.gsub(/_(.)/) { $1.upcase }
      Capistrano::Deploy::SCM.const_get(scm_const).new(:repository => var[:repository])
    }
  end
end
