require 'grape'
require 'spec_helper'

describe Grape::Reload::Watcher do
  def app; @app end
  before(:example) do
    @app =
        Grape::RackBuilder.setup do
          add_source_path File.expand_path('**.rb', APP_ROOT)
          add_source_path File.expand_path('**/*.rb', APP_ROOT)
          environment 'development'
          reload_threshold 0
          mount 'Test::App1', to: '/test1'
          mount 'Test::App2', to: '/test2'
        end.boot!.application
  end

  after(:example) do
    Grape::Reload::Watcher.clear
  end

  it 'reloads changed root app file' do
    get '/test1/test'
    expect(last_response).to succeed
    expect(last_response.body).to eq('test1 response')

    with_changed_fixture 'app1/test1.rb' do
      get '/test1/test'
      expect(last_response).to succeed
      expect(last_response.body).to eq('test1 response changed')
    end
  end

  it 'reloads mounted app file' do
    get '/test1/mounted/test1'
    expect(last_response).to succeed
    expect(last_response.body).to eq('mounted test1')

    with_changed_fixture 'app1/mounts/mount.rb' do
      get '/test1/mounted/test1'
      expect(last_response).to succeed
      expect(last_response.body).to eq('mounted test1 changed')
    end
  end

  it 'remounts class on different root' do
    get '/test2/mounted/test'
    expect(last_response).to succeed
    expect(last_response.body).to eq('test')

    with_changed_fixture 'app2/test2.rb' do
      get '/test2/mounted/test'
      expect(last_response).to_not succeed

      get '/test2/mounted2/test'
      expect(last_response).to succeed
    end
  end

  it 'reloads library file and reinits all affected APIs' do
    with_changed_fixture 'app1/test1.rb' do
      get '/test1/lib_mounted/lib_string'
      expect(last_response).to succeed
      expect(last_response.body).to eq('lib string 1')

      with_changed_fixture 'lib/lib1.rb' do
        get '/test1/lib_mounted/lib_string'
        expect(last_response).to succeed
        expect(last_response.body).to eq('lib string 1 changed')

        expect(Test::LibMount1.endpoints.first.options[:route_options][:entity].first.get_lib_string).to eq('lib string 1 changed')
      end
    end
  end
end