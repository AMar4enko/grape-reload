module Test
  class Mount1 < Grape::API
    get :test1 do
      'mounted test1' #changed: 'mounted test1 changed'
    end
  end
end