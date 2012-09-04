module Clementine

  class Error < StandardError; end

  class ClojureScriptEngine
    def initialize(file, options)
      @file = file
      @options = options
      @classpath = CLASSPATH
    end

    def compile
      @options = Clementine.options if @options.empty?
      begin
        cmd = %Q{#{command} #{@file} '#{convert_options(@options)}' 2>&1}
        result = `#{cmd}`
      rescue Exception
        raise Error, "compression failed: #{result || $!}"
      end
      unless $?.exitstatus.zero?
        raise Error, result
      end
      result
    end

    def nailgun_prefix
      server_address = Nailgun::NailgunConfig.options[:server_address]
      port_no  = Nailgun::NailgunConfig.options[:port_no]
      "#{Nailgun::NgCommand::NGPATH} --nailgun-port #{port_no} --nailgun-server #{server_address}"
    end

    def setup_classpath_for_ng
      current_cp = `#{nailgun_prefix} ng-cp`
      unless current_cp.include? "clojure.jar"
        puts "Initializing nailgun classpath, required clementine dependencies missing"
        `#{nailgun_prefix} ng-cp #{@classpath.join " "}`
      end
    end

    def command
      if defined? Nailgun
        setup_classpath_for_ng
        [nailgun_prefix, 'clojure.main', "#{CLOJURESCRIPT_HOME}/bin/cljsc.clj"].flatten.join(' ')
      else
        ["java", '-cp', "\"#{@classpath.join ":"}\"", 'clojure.main', "#{CLOJURESCRIPT_HOME}/bin/cljsc.clj"].flatten.join(' ')
      end
    end

    # private
    def convert_options(options)
      opts = ""
      options.each do |k, v|
        cl_key = ":" + Clementine.ruby2clj(k.to_s)
        case
        when (v.kind_of? Symbol)
          cl_value = ":" + Clementine.ruby2clj(v.to_s)
        when v.is_a?(TrueClass) || v.is_a?(FalseClass)
          cl_value = v.to_s
        else
          cl_value = "\"" + v + "\""
        end
        opts += cl_key + " " + cl_value + " "
      end
      "{" + opts.chop! + "}"
    end

    # TODO: this is pasted from ClojureScriptEngine. let's fix that.
    def default_opts
      key = "output_dir"
      value = ""
      if defined?(Rails)
        value = File.join(Rails.root, "app", "assets", "javascripts", "clementine")
      else
        value = Dir.pwd
      end
      {key => value}
    end
  end
end
