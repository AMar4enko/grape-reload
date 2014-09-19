

module Grape
  module Reload
    module Storage
      class << self
        def clear!
          files.each_key do |file|
            remove(file)
            Watcher.remove_feature(file)
          end
          @files = {}
        end

        def remove(name)
          file = files[name] || return
          file[:constants].each{ |constant| Watcher.remove_constant(constant) }
          file[:features].each{ |feature| Watcher.remove_feature(feature) }
          files.delete(name)
        end

        def prepare(name)
          file = remove(name)
          @old_entries ||= {}
          @old_entries[name] = {
              :constants => ObjectSpace.classes,
              :features  => old_features = Set.new($LOADED_FEATURES.dup)
          }
          features = file && file[:features] || []
          features.each{ |feature| Watcher.safe_load(feature, :force => true) unless Watcher.feature_excluded?(feature)}
          Watcher.remove_feature(name) if old_features.include?(name)
        end

        def commit(name)
          entry = {
              :constants => ObjectSpace.new_classes(@old_entries[name][:constants]),
              :features  => Set.new($LOADED_FEATURES) - @old_entries[name][:features] - [name]
          }
          files[name] = entry
          @old_entries.delete(name)
        end

        def rollback(name)
          new_constants = ObjectSpace.new_classes(@old_entries[name][:constants])
          new_constants.each{ |klass| Watcher.remove_constant(klass) }
          @old_entries.delete(name)
        end

        private

        def files
          @files ||= {}
        end
      end
    end
  end
end