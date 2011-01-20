ext :hudson do
  var[:hudson,:root] = lambda { "/tmp/hudson" }
  var[:hudson,:jobs,:root] = lambda { "#{var[:hudson,:root]}/jobs" }
  var[:hudson,:conf,:path] = lambda { "#{var[:hudson,:jobs,:root]}/#{conf_name}/config.xml" }

  require 'rexml/document'
  require 'rexml/formatters/transitive'

  class HudsonXmlConfigurator
    attr :root
    
    def initialize(conf, root)
      @conf = conf
      @root = root
    end
    
    def var(*args, &block)
      @conf.var(*args, &block)
    end
    
    def _!(name, attrs = nil, text = nil, &block)
      name = name + "!" unless name =~ /!$/
      _(name, attrs, text, &block)
    end
    
    def _(name, attrs = nil, text = nil, &block)
      if text.nil? && !attrs.nil? && !attrs.respond_to?(:keys)
        text = attrs
        attrs = nil
      end
      
      name_str = name.to_s
      nested_element = (name_str !~ /!$/ and @root.elements.find { |elem| elem.name == name_str }) || @root.add_element(name_str.chomp("!"))
      
      attrs.each { |k,v| nested_element.add_attribute(k.to_s, v.to_s) } unless attrs.nil?
      nested_element.add_text(text.to_s) unless text.nil?
      
      HudsonXmlConfigurator.new(@conf, nested_element).instance_eval(&block) if block
    end
    
    def method_missing(name, attrs = nil, text = nil, &block)
      _(name, attrs, text, &block)
    end
    
    def respond_to?(name, include_private = false)
      true
    end

    def to_s
      sio = StringIO.new
      formatter = REXML::Formatters::Transitive.new
      formatter.write(@root, sio)
      sio.string
    end
  end

end

conf :hudson do
  def configure
    require 'fileutils'

    $top.select { with_method(:configure_hudson) }.each do |conf|
      FileUtils.mkdir_p(File.dirname(conf.var[:hudson,:conf,:path]))
      open(conf.var[:hudson,:conf,:path], "w") { |f| f.write(conf.configure_hudson.to_s) }
    end
  end
end

conf :hudson_support do
  use :hudson

  def new_hudson_job
    configurator = HudsonXmlConfigurator.new(self, REXML::Document.new << REXML::XMLDecl.new(REXML::XMLDecl::DEFAULT_VERSION, "utf-8"))
    configurator.instance_eval {
      project {
        actions {}
        description("")
        keepDependencies(false)
        properties {}

        canRoam(true)
        disabled(false)

        triggers {}
        builders {}
        publishers {}
        buildWrappers {}
      }
    }
    
    hudson_job = ->(&block) { configurator.instance_eval(&block) if block }
    class << hudson_job; self; end.class_eval do
      alias_method :configure, :call;
      define_method :to_s do
        configurator.to_s
      end
    end
    hudson_job
  end
end

### Specific Hudson extensions
defn hudson.quiet_period do
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        quietPeriod(var[:quiet_period])
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.remote_job_trigger do
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        authToken(var[:auth_token])
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.parametrized_job do
  var(:default) { "" }
  
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        properties {
          _("hudson.model.ParametersDefinitionProperty") {
            parameterDefinitions {
              _!("hudson.model.StringParameterDefinition") {
                name(var[:name])
                description(var[:description])
                defaultValue(var[:default])
              }
            }
          }
        }
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.subversion_scm do
  var[:use_update] = ->{ false }
  
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        scm(:class => "hudson.scm.SubversionSCM") {
          locations {
            _("hudson.scm.SubversionSCM_-ModuleLocation") {
              remote(var?[:svn,:repository] || var[:repository])
              local("")
            }
          }
          useUpdate(var[:use_update])
        }
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.no_scm do
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        scm(:class => "hudson.scm.NullSCM")
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.timer_trigger do
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        triggers(:class => "vector") {
          _("hudson.triggers.SCMTrigger") {
            spec(var[:poll,:pattern])
          }
        }
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.seleniumhq_builder do
  var(:browser) { "*firefox" }
  var(:result_file) { "selenium_report.html" }
  var(:other) { "" }
  
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        builders {
          _("hudson.plugins.seleniumhq.SeleniumhqBuilder") {
            browser(var[:browser])
            startURL(var[:start_url])
            suiteFile(var[:suite_url])
            resultFile(var[:result_file])
            other(var[:other])
          }
        }
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.build_trigger_publisher do
  var(:child_projecs) { [] }
  
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        publishers {
          _("hudson.tasks.BuildTrigger") {
            childProjects(var[:child_projects].join(","))
            threshold {
              name("SUCCESS")
              ordinal(0)
              color("BLUE")
            }
          }
        }
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.parametrized_build_trigger_publisher do
  body { |hudson_job = new_hudson_job|
    hudson_job {
      project {
        publishers {
          _("hudson.plugins.parameterizedtrigger.BuildTrigger") {
            configs {
              _!("hudson.plugins.parameterizedtrigger.PredefinedPropertiesBuildTriggerConfig") {
                projectsValue(opts[:projects] || "")
                properties(opts[:properties] || "")
                condition({ :class => "hudson.plugins.parameterizedtrigger.ResultCondition" }, (opts[:condition] || "SUCCESS").upcase)
                includeCurrentParameters(opts.fetch(:include_current_params, false))
              }
            }
          }
        }
      }
    }
  }
end

defn hudson.timer_trigger do
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        triggers(:class => "vector") {
          _("hudson.triggers.TimerTrigger") {
            spec(var[:timer,:pattern])
          }
        }
      }
    }
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.shell_builder do
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        builders {
          _("hudson.tasks.Shell") {
            var[:command]
          }
        }
      }
    }
    
    has_next? ? call_next(hudson_job) : hudson_job
  }
end

defn hudson.jabber_publisher do
  var(:defualt_recipients) { [] }
  var(:notification_strategy) { "ALL" }
  var(:notify_on_build_start) { false }
  var(:notify_suspects) { true }
  var(:notify_fixers) { true }
  
  body { |hudson_job = new_hudson_job|
    hudson_job.configure {
      project {
        publishers {
          _("hudson.plugins.jabber.im.transport.JabberPublisher") {
            targets(:class => "linked-list") {
              var[:default_recipients].each do |recipient|
                _("hudson.plugins.jabber.im.DefaultIMMessageTarget") {
                  value(recipient)
                }
              end
            }
            notificationStrategy({ :class => "hudson.plugins.jabber.NotificationStrategy"}, var[:notification_strategy])
            notifyOnBuildStart(var[:notify_on_build_start])
            notifySuspects(var[:notify_suspects])
            notifyFixers(var[:notify_fixers])
          }
        }
      }
    }

    has_next? ? call_next(hudson_job) : hudson_job
  }

end
