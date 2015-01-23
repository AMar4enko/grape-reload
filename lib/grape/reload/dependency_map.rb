require_relative '../../ripper/extract_constants'

module Grape
  module Reload
    class UnresolvedDependenciesError < RuntimeError
      def message; 'One or more unresolved dependencies found' end
    end


    class DependencyMap
      extend Forwardable
      include TSort

      attr_accessor :map

      def tsort_each_child(node, &block)
        @files_linked.fetch(node).each(&block)
      end

      def tsort_each_node(&block)
        @files_linked.each_key(&block)
      end

      def initialize(sources)
        @sources = sources
        files = @sources.map{|p| Dir[p]}.flatten.uniq
        @map = Hash[files.zip(files.map do |file|
                                begin
                                  Ripper.extract_constants(File.read(file))
                                rescue
                                  Grape::RackBuilder.logger.error("Theres is an error while parsing #{file}")
                                  []
                                end
                              end)]
      end

      def sorted_files
        tsort
      end

      def files
        map.keys
      end

      def dependent_classes(loaded_file)
        classes = []
        sorted = sorted_files
        cycle_classes = ->(file, visited_files = []){
          return if visited_files.include?(file)
          visited_files ||= []
          visited_files << file
          classes |= map[file][:declared]
          map[file][:declared].map{|klass|
            file_class = map.each_pair
                .sort{|a1, a2|
                  sorted.index(a1.first) - sorted.index(a2.first)
                }
                .select{|f, const_info| const_info[:used].include?(klass) }
                .map{|k,v| [k,v[:declared]]}

            file_class.each {|fc|
              classes |= fc.last
              cycle_classes.call(fc.first, visited_files)
            }
          }
        }
        cycle_classes.call(loaded_file)
        classes
      end

      def fs_changes(&block)
        result = {
          added: [],
          removed: [],
          changed: []
        }
        files = @sources.map{|p| Dir[p]}.flatten.uniq
        result[:added] = files - map.keys
        result[:removed] = map.keys - files
        result[:changed] = map.keys.select(&block)
        result
      end

      def class_file(klass)
        @file_class['::'+klass.to_s]
      end

      def files_reloading(&block)
        yield
        initialize(@sources)
        resolve_dependencies!
      end

      def resolve_dependencies!
        @file_class = Hash[map.each_pair.map{|file, hash|
          hash[:declared].zip([file]*hash[:declared].size)
        }.flatten(1)]
        @files_linked = {}

        unresolved_classes = {}
        lib_classes = []
        map.each_pair do |file, const_info|
          @files_linked[file] ||= []
          const_info[:used].each_with_index do |variants, idx|
            next if lib_classes.include?(variants.last)
            variant = variants.find{|v| @file_class[v]}
            if variant.nil?
              const_ref = variants.last
              begin
                const_ref.constantize
                lib_classes << const_ref
              rescue
                unresolved_classes[const_ref] ||= []
                unresolved_classes[const_ref] << file
              end
            else
              @files_linked[file] << @file_class[variant] unless @files_linked[file].include?(@file_class[variant])
              const_info[:used][idx] = variant
            end
          end
        end

        unresolved_classes.each_pair do |klass, filenames|
          filenames.each {|filename| Grape::RackBuilder.logger.error("Unresolved const reference #{klass} from: #{filename}".colorize(:red)) }
        end

        Grape::RackBuilder.logger.error("One or more unresolved dependencies found".colorize(:red)) if unresolved_classes.any?
      end
    end

    class Sources
      extend Forwardable
      def_instance_delegators :'@dm', :sorted_files, :class_file, :fs_changes, :dependent_classes, :files_reloading
      def initialize(sources)
        @sources = sources
        @dm = DependencyMap.new(sources)
        @dm.resolve_dependencies!
      end

      def file_excluded?(file)
        @sources.find{|path| File.fnmatch?(path, file) }.nil?
      end
    end
  end
end