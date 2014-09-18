module Test
  class LibMount2 < Grape::API
    get :lib_string do
      Test::Lib2.get_lib_string
    end
  end
end