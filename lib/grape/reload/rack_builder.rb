require 'active_support/inflector'
require_relative '../reload/watcher'
require_relative '../reload/grape_api'
require_relative '../reload/dependency_map'


RACK_ENV = ENV["RACK_ENV"] ||= "development"  unless defined?(RACK_ENV)

module Grape
  module RackBuilder
    module LoggingStub
      class << self
        [:error, :debug, :exception, :info, :devel].each do |level|
          define_method(level){|*args|
            # Silence all reloader output by default with stub
          }
        end
      end
    end

    class MountConfig
      attr_accessor :app_class, :options, :mount_root
      def initialize(options)
        options.each_pair{|k,v| send(:"#{k}=", v) }
      end
    end

    class Config
      attr_accessor :mounts, :sources, :options

      {environment: RACK_ENV, reload_threshold: 1, logger: LoggingStub}.each_pair do |attr, default|
        attr_accessor attr
        define_method(attr) { |value = nil|
          @options ||= {}
          @options[attr] = value if value
          @options[attr] || default
        }
      end

      def add_source_path(glob)
        (@sources ||= []) << glob
      end

      def mount(app_class, options)
        mounts << MountConfig.new(
            app_class: app_class,
            mount_root: options.delete(:to) || '/',
            options: options
        )
      end

      def mounts
        @mounts ||= []
      end
    end

    module ClassMethods
      def setup(&block)
        config.instance_eval(&block)
        self
      end

      def boot!
        Grape::Reload::Watcher.setup(sources: Grape::Reload::Sources.new(config.sources))
        self
      end

      def application
        return @rack_app if @rack_app
        mounts = config.mounts
        environment = config.environment
        reload_threshold = config.reload_threshold
        @rack_app = ::Rack::Builder.new do
          mounts.each_with_index do |m|
            if environment == 'development'
              r = Rack::Builder.new
              r.use Grape::ReloadMiddleware[reload_threshold]
              r.run m.app_class.constantize
              map(m.mount_root) { run r }
            else
              map(m.mount_root) { run m.app_class.constantize }
            end
          end
        end
      end

      def mounted_apps_of(file)
        config.mounts.select { |mount| File.identical?(file, Grape::Reloader.root(mount.app_file)) }
      end

      def reloadable_apps
        config.mounts
      end

      def logger
        config.logger
      end

      private
      def config
        @config ||= Config.new
      end
    end
    class << self
      include Grape::RackBuilder::ClassMethods
    end
  end
end