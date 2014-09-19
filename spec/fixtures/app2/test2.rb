module Test
  class App2 < Grape::API
    format :txt
    mount Test::Mount2 => '/mounted' #changed: mount Test::Mount2 => '/mounted2'
    get :test do
      'test2 response changed'
    end
  end
end