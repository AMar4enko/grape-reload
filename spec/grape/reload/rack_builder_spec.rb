require 'spec_helper'

describe Grape::RackBuilder do
  let(:builder) {
    Module.new do
      class << self
        include Grape::RackBuilder::ClassMethods
        def get_config
          config
        end
      end
    end
  }
  let(:middleware) {
    Class.new do
      def initialize(app)
        @app = app
      end
      def call(env)
        @app.call(env)
      end
    end
  }


  before do
    builder.setup do
      environment 'development'
      add_source_path File.expand_path('**/*.rb', APP_ROOT)
    end
  end
  before :each do
    builder.get_config.mounts.clear
  end

  describe '.setup' do
    subject(:config){ builder.get_config }

    it 'configures builder with options' do
      expect(config.sources).to include(File.expand_path('**/*.rb', APP_ROOT))
      expect(config.environment).to eq('development')
    end

    it 'allows to mount bunch of grape apps to different roots' do
      builder.setup do
        mount 'TestClass1', to: '/test1'
        mount 'TestClass2', to: '/test2'
      end
      expect(config.mounts.size).to eq(2)
    end

    it 'allows to add middleware' do
      builder.setup do
        use middleware do
        end
      end
      expect(config.middleware.size).to eq(1)
    end
  end

  describe '.boot!' do
    before(:each) do
      builder.setup do
        mount 'Test::App1', to: '/test1'
        mount 'Test::App2', to: '/test2'
      end
    end

    it 'autoloads mounted apps files' do
      expect{ builder.boot! }.to_not raise_error
      expect(defined?(Test::App1)).not_to be_nil
      expect(defined?(Test::App2)).not_to be_nil
    end

    it 'autoloads apps dependencies, too' do
      expect{ builder.boot! }.to_not raise_error
      expect(defined?(Test::Mount1)).not_to be_nil
      expect(defined?(Test::Mount2)).not_to be_nil
    end
  end

  describe '.application' do
    before(:each) do
      builder.setup do
        use middleware
        mount 'Test::App1', to: '/test1'
        mount 'Test::App2', to: '/test2'
      end
      builder.boot!
    end
    it 'creates Rack::Builder application' do
      expect{ @app = builder.application }.not_to raise_error
      expect(@app).to be_an_instance_of(Rack::Builder)
      def @app.get_map; @map end
      def @app.get_use; @use end
      expect(@app.get_use.size).to eq(1)
      expect(@app.get_map.keys).to include('/test1','/test2')
    end
  end
end