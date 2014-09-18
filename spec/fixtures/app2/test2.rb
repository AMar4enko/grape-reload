module Test
  class App2 < Grape::API
    format :txt
    mount Test::Mount2 => '/mounted'
    # mount Test::Mount10 => '/mounted2'
    mount Test::LibMount2 => '/lib_mounted'
    #changed: mount Test::LibMount2 => '/lib_mounted'
    get :test do
      'test2 response' #changed: 'test2 response changed'
    end
  end
end