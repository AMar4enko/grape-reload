module Rack
  class Cascade
    def reinit!
      @apps.map{|app| app.reinit! if app.respond_to?('reinit!') }
    end
  end
end