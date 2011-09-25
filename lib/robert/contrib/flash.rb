ext :flash_builder do
  class FlashXmlBuilder
    def initialize(project_name)
      @doc = REXML::Document.new
      @project = REXML::Element.new("project", @doc)
      @project.attributes["name"] = project_name
    end

    def add_taskdef(resource, classpath)
      taskdef = REXML::Element.new("taskdef", @project)
      taskdef.attributes["resource"] = resource
      taskdef.attributes["classpath"] = classpath
    end

    def add_property(name, value)
      property = REXML::Element.new("property", @project)
      property.attributes["name"] = name
      property.attributes["value"] = value
    end

    def add_compc_directive
      @directive = REXML::Element.new("compc", @project)
    end

    def add_mxmlc_directive
      @directive = REXML::Element.new("mxmlc", @project)
    end

    def set_debug(flag)
      @directive.attributes["debug"] = flag.to_s
    end

    def set_mxml_target_path(path)
      @directive.attributes["file"] = path  
    end

    def set_include_classes(classes)
      @directive.attributes["include-classes"] = classes.join(" ")
    end

    def set_headless(headless)
      @directive.attributes["headless-server"] = (headless ? "true" : "false")
    end

    def set_default_background_color(color)
      @directive.attributes["default-background-color"] = color
    end

    def set_default_frame_rate(rate)
      @directive.attributes["default-frame-rate"] = rate.to_s
    end

    def add_source_path(path)
      sp = REXML::Element.new("compiler.source-path", @directive)
      sp.attributes["path-element"] = path
    end

    def set_locale(*locales)
      @directive["locale"] = locales.join("")
    end

    def add_library_path(path)
      library_path = REXML::Element.new("compiler.library-path", @directive)
      library_path.attributes["append"] = "true"
      library_path.attributes["dir"] = path
      library_path.attributes["includes"] = "*.swc"
    end

    def set_compatibility_version(version)
      @directive.attributes["compatibility-version"] = version
    end

    def set_static_link_runtime_shared_libraries(flag)
      @directive.attributes["static-link-runtime-shared-libraries"] = flag.to_s
    end

    def set_target_player(player_version)
      @directive.attributes["target-player"] = player_version.to_s
    end

    def set_theme(path)
      theme = REXML::Element.new("compiler.theme", @directive)
      theme.attributes["dir"] = File.dirname(path)
      theme.attributes["includes"] = File.basename(path)
    end

    def add_load_config(path)
      load_config = REXML::Element.new("load-config", @directive)
      load_config.attributes["filename"] = path
    end

    def set_output(path)
      @directive.attributes["output"] = path
    end

    def write(io)
      @doc.write(io, 3)
    end
  end
end

defn flash_builder.dependencies do
  body {
    sources
        
    properties_fpath = "#{revision_build.src_path}/.actionScriptProperties"
    if File.exists?(properties_fpath)
      propertiex_xml = open(properties_fpath, "r") { |f| f.read }
      
      doc = REXML::Document.new propertiex_xml
      entries = REXML::XPath.match(doc, %q{//libraryPathEntry[@kind='3']/@path})
      
      deps = entries.inject([]) do |result, entry|
        result << $1 if entry.value =~ /^\/(.+?)\//
        result
      end
      deps
    else
      []
    end
  }
end

defn flash_builder.patch_sources do
  body {
    flex_sdk_path = var[:flex_sdk,:path]
    
    builder = FlashXmlBuilder.new(project_name)
    builder.add_taskdef("flexTasks.tasks", "#{flex_sdk_path}/ant/lib/flexTasks.jar")
    builder.add_property("FLEX_HOME", flex_sdk_path)
    builder.add_property("APP_ROOT", revision_build.patched_src_path)

    call_next(builder)

    builder.add_load_config("#{flex_sdk_path}/frameworks/" + var?[:use_air] ? "air-config.xml" : "flex-config.xml"))       
    builder.add_source_path("#{revision_build.patched_src_path}/#{var?[:src_path] || "src"}")
    assets_path = "#{revision_build.patched_src_path}/#{var?[:assets_path] || "assets"}"
    builder.add_source_path(assets_path) if File.directory?(assets_path)
    builder.set_headless(var?[:headless])
    builder.set_target_player(var[:target_flash_player]) if var?[:target_flash_player]
    builder.set_compatibility_version(var[:flex_compatibility_version]) if var?[:flex_compatibility_version]
    builder.set_static_link_runtime_shared_libraries(var[:flex_static_link_runtime_shared_libraries]) if var?[:flex_static_link_runtime_shared_libraries]
    builder.set_theme(var[:flex_theme]) if var?[:flex_theme]
    builder.set_debug(var[:flex_debug]) if var?[:flex_debug]

    search_paths = (var?[:flex_libraries_path] || []).dup
    search_paths << "#{flex_sdk_path}/frameworks/libs"
    search_paths << "#{flex_sdk_path}/frameworks/libs/air" if var?[:use_air]
    search_paths.each { |sp| builder.add_library_path(sp) }

    build_xml_path = "#{revision_build.patched_src_path}/build.xml"
    open(build_xml_path, "w") { |f| builder.write(f) }
  }
end

defn flash_builder.patch_library_sources do
  body { |builder|
    builder.add_compc_directive
    classes = nil
    Dir.chdir("#{revision_build.patched_src_path}/#{var?[:src_path] || "src"}") do
      classes = Dir["**/*"].inject([]) do |memo, cls|
        if cls =~ /(.*)\.(as|mxml)$/
          memo << $1.gsub(/\//, ".")
        end
        memo
      end
    end
    builder.set_include_classes(classes)
    
    output_name = var?[:output_swf_name] || "#{project_name}.swc"
    output_path = "#{revision_build.dist_path}/#{output_name}"
    builder.set_output(output_path)        
  }
end

defn flash_builder.patch_application_sources do
  body { |builder|
    builder.add_mxmlc_directive
    target_path = var?[:mxml_target] || "#{project_name}.mxml"
    target_path = "#{revision_build.patched_src_path}/#{var?[:src_path] || "src"}/target_path"
    builder.set_mxml_target_path(target_path)
    builder.set_default_frame_rate(var?[:default_frame_rate] || 24)
    builder.set_default_background_color(var?[:default_background_color] || "0xffffff")
    
    output_name = var?[:output_swf_name] || "#{project_name}.swf"
    output_path = "#{revision_build.dist_path}/#{output_name}"
    builder.set_output(output_path)    
  }
end

defn flash_builder.patch_air_descriptor do
  body {
    app_descr_file = var?[:app_descr_target] || "#{project_name}-app.xml"
    open("#{revision_build.patched_src_path}/#{var?[:src_path] || "src"}/#{app_descr_file}"), "r" do |fin|
      src_contents = fin.read
      ([""] + (1..3).map { |i| i.to_s }).each do |suffix|
        contents = src_contents.gsub(project_name, project_name + suffix)
        contents = contents.gsub("[This value will be overwritten by Flex Builder in the output app.xml]", "#{project_name}.swf")
        open File.join(revision_build.dist_path, "#{project_name}#{suffix}-app.xml"), "w" do |fout|
          fout.write contents
        end
      end
    end    
  }
end

conf :flash_builder_library do
  use :flash_builder

  act[:build_dependencies] = flash_builder.dependencies
  act[:src_patch] = flash_builder.patch_sources(flash_builder.patch_library_sources)
  act[:build] = build.sh { var[:cmd] = "env ANT_OPTS=-Xmx500M ant" }
end

conf :flash_builder_application do
  use :flash_builder

  act[:build_dependencies] = flash_builder.dependencies
  act[:src_patch] = flash_builder.patch_sources(flash_builder.patch_application_sources)
  act[:build] = build.sh { var[:cmd] = "env ANT_OPTS=-Xmx500M ant" }
end

conf :flash_builder_air_application do
  include :flash_builder_application

  act[:build] = seq(act[:build], flash_builder.patch_air_descriptor)
end
