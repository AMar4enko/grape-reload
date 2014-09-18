module Test
  class App1 < Grape::API
    format :txt
    mount Test::Mount1 => '/mounted'
    #changed: mount Test::LibMount1 => '/lib_mounted'
    get :test do
      'test1 response' #changed: 'test1 response changed'
    end
  end
end