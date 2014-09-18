module Test
  class LibMount1 < Grape::API
    desc 'Some test description',
         entity: [Test::Lib1]
    get :lib_string do
      Test::Lib1.get_lib_string
    end
  end
end