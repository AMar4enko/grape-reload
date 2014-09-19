module Test
  class Mount2 < Grape::API
    get :test do
      'test'
    end
  end
end