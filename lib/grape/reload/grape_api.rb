require 'grape'

module Grape
  class ReloadMiddleware
    class << self
      def [](threshold)
        threshold ||= 2
        eval <<CLASS
      Class.new(Grape::ReloadMiddleware) {
        private
        def reload_threshold
          #{threshold > 0 ? threshold.to_s+".seconds" : "false" }
        end
      }
CLASS
      end
    end

    def initialize(app)
      @app_klass = app
    end

    def call(*args)
      if reload_threshold && (Time.now > (@last || reload_threshold.ago) + 1)
        Thread.list.size > 1 ? Thread.exclusive { Grape::Reload::Watcher.reload! } : Grape::Reload::Watcher.reload!
        @last = Time.now
      else
        Thread.list.size > 1 ? Thread.exclusive { Grape::Reload::Watcher.reload! } : Grape::Reload::Watcher.reload!
      end
      @app_klass.constantize.call(*args)
    end
    def reload_threshold; 2.seconds end
  end
end

module Grape
  module Reload
    module AutoreloadInterceptor
      [:set, :nest, :route, :imbue, :mount, :desc, :params, :helpers, :format, :formatter, :parser, :error_formatter, :content_type].each do |method|
        eval <<METHOD
        def #{method}(*args, &block)
          class_declaration << [:#{method},args,block]
          super(*args, &block)
        end
METHOD
      end

      def reinit!
        declaration = class_declaration.dup
        @class_decl = []
        endpoints.each { |e| e.options[:app].reinit! if e.options[:app] }
        reset!
        declaration.each {|decl|
          send(decl[0],*deep_reconstantize.call(decl[1]),&decl[2])
        }
        change!
      end

      def recursive_!

      end
    private
      def class_declaration
        @class_decl ||= []
      end
      def deep_reconstantize
        proc = ->(value) {
          case value
            when Hash
              Hash[value.each_pair.map { |k,v| [proc.call(k), proc.call(v)] }]
            when Array
              value.map { |v| proc.call(v) }
            when Class
              return if value.to_s[0,2] == '#<'
              value.to_s.constantize
            else
              value
          end
        }
      end
    end
  end
end

Grape::API.singleton_class.class_eval do
  alias_method :inherited_shadowed, :inherited
  alias_method :settings_shadowed, :settings
  def inherited(*args)
    inherited_shadowed(*args)
    args.first.singleton_class.class_eval do
      include Grape::Reload::AutoreloadInterceptor
    end
  end
end