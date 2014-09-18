require 'padrino-core/reloader/rack'
require 'padrino-core/reloader'
require 'padrino-core/logger'
require 'padrino-support/core_ext/object_space'
require 'logging'
require 'ripper'
require_relative 'rack_builder'
require_relative 'storage'

module Grape
  module Reload
    module Watcher
      class << self
        MTIMES = {}
        # include Padrino::Reloader
        attr_reader :sources
        def rack_builder; Grape::RackBuilder end

        def logger; Grape::RackBuilder.logger end

        def safe_load(file, options={})
          began_at = Time.now
          return unless options[:force] || file_changed?(file)
          # return require(file) if feature_excluded?(file)

          Storage.prepare(file) # might call #safe_load recursively
          logger.devel((file_new?(file) ? "loading" : "reloading") + "#{file}" )
          begin
            with_silence{ require(file) }
            Storage.commit(file)
            update_modification_time(file)
          rescue Exception => exception
            unless options[:cyclic]
              logger.exception exception, :short
              logger.error "Failed to load #{file}; removing partially defined constants"
            end
            Storage.rollback(file)
            raise
          end
        end

        ##
        # Tells if a feature should be excluded from Reloader tracking.
        #
        def remove_feature(file)
          $LOADED_FEATURES.delete(file) unless feature_excluded?(file)
        end

        ##
        # Tells if a feature should be excluded from Reloader tracking.
        #
        def feature_excluded?(file)
          @sources.file_excluded?(file)
        end

        def constant_excluded?(const)
          @sources.class_file(const).nil?
        end

        def files_for_rotation
          files = Set.new
          files += @sources.sorted_files.map{|p| Dir[p]}.flatten.uniq
        end

        def setup(options)
          @sources = options[:sources]
          load_files!
        end

        ###
        # Macro for mtime update.
        #
        def update_modification_time(file)
          MTIMES[file] = File.mtime(file)
        end


        def clear
          MTIMES.each_key{|f| Storage.remove(f)}
          MTIMES.clear
        end

        def load_files!
          files_to_load = files_for_rotation.to_a
          tries = {}
          while files_to_load.any?
            f = files_to_load.shift
            tries[f] = 1 unless tries[f]
            begin
              safe_load(f, cyclic: true, force: true)
            rescue
              logger.error $!
              tries[f] += 1
              if tries[f] < 3
                files_to_load << f
              else
                raise
              end
            end
          end
        end

        def reload!
          files = @sources.fs_changes{|file|
            File.mtime(file) > MTIMES[file]
          }
          changed_files_sorted = @sources.sorted_files.select{|f| files[:changed].include?(f)}
          @sources.files_reloading do
            changed_files_sorted.each{|f| safe_load(f)}
          end
          changed_files_sorted.map{|f| @sources.dependent_classes(f) }.flatten.uniq.each {|class_name|
            if (klass = class_name.constantize) < Grape::API
              klass.reinit!
            end
          }
        end

        ##
        # Removes the specified class and constant.
        #
        def remove_constant(const)
          return if constant_excluded?(const)
          base, _, object = const.to_s.rpartition('::')
          base = base.empty? ? Object : base.constantize
          base.send :remove_const, object
          logger.devel "Removed constant #{const} from #{base}"
        rescue NameError
        end

        ###
        # Returns true if the file is new or it's modification time changed.
        #
        def file_changed?(file)
          file_new?(file) || File.mtime(file) > MTIMES[file]
        end

        def file_new?(file)
          MTIMES[file].nil?
        end

        private
        def with_silence
          verbosity_level, $-v = $-v, nil
          yield
        ensure
          $-v = verbosity_level
        end
      end
    end
  end
end