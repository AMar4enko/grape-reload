require 'spec_helper'
require_relative '../../../lib/grape/reload/grape_api'
describe Grape::Reload::AutoreloadInterceptor do
  let!(:api_class) {
    nested_class = Class.new(Grape::API) do
      namespace :nested do
        get :route do
          'nested route'
        end
      end
    end

    versioned_class = Class.new(Grape::API) do
      version :v1
      get 'versioned_route' do
        'versioned route'
      end
    end

    Class.new(Grape::API) do
      format :txt
      get :test_route do
        'test'
      end
      mount nested_class => '/nested'
      mount versioned_class
    end
  }

  describe '.reinit!' do
    let!(:app) {
      app = Rack::Builder.new
      app.run api_class
      app
    }
    it 'exists' do
      expect(api_class).to respond_to('reinit!')
    end

    it 'reinit Grape API declaration' do
      get '/test_route'
      expect(last_response).to succeed
      expect(last_response.body).to eq('test')
      get '/nested/nested/route'
      expect(last_response).to succeed
      expect(last_response.body).to eq('nested route')
      api_class.reinit!
      get '/test_route'
      expect(last_response).to succeed
      expect(last_response.body).to eq('test')
      get '/nested/nested/route'
      expect(last_response).to succeed
      expect(last_response.body).to eq('nested route')
    end

    it 'preserves the API version' do
      get '/v1/versioned_route'
      expect(last_response).to succeed
      expect(last_response.body).to eq('versioned route')
      api_class.reinit!
      get '/v1/versioned_route'
      expect(last_response).to succeed
      expect(last_response.body).to eq('versioned route')
    end

  end
end
