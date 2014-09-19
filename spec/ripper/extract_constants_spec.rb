require 'spec_helper'
require 'ripper/extract_constants'

describe 'Ripper.extract_consts' do
  let!(:code1) {
<<CODE
class TopClass
end

module Test
  class Test1
  end

  module Test2
    class Test4
    end

    class InClassUsage
      t1 = ::TopClass
      t2 = Test1
      t3 = Test::Test1
      t4 = Test2::Test4
      t5 = Test::NotExists::Test1
    end
  end

  CONST_DEF1 = Test::Test2::InClassUsage
  CONST_DEF2 = Test3::AnotherClass
  CONST_DEF3 = SomeExternalClass
  class Test < Superclass
    test_class_method {params: SomeClass}

    def test_method
      SomeClass1.call_method
      arg = SomeClass2.new
    end
  end
end
CODE
  }

  let!(:code2) {
  <<CODE
  module Test
    class App2 < Grape::API
      format :txt
      mount Test::Mount2 => '/mounted'
      mount Test::Mount10 => '/mounted2'
      desc 'Blablabla',
        entity: [Test::SomeAnotherEntity]
      get :test do
        SomeClass.usage
        'test2 response'
      end
    end
  end
  class WithoutModule
    def use_top_level
      TopLevel.new
    end
  end
CODE
  }

  it 'extract consts from code1 correctly' do
    consts = Ripper.extract_constants(code1)
    expect(consts[:declared].flatten).to include(
                '::TopClass',
                '::Test::Test1',
                '::Test::Test2::Test4',
                '::Test::Test2::InClassUsage',
                '::Test::CONST_DEF1',
                '::Test::CONST_DEF2',
                '::Test::CONST_DEF3',
                '::Test::Test'
            )

    expect(consts[:used].flatten).to include(
                '::Test3::AnotherClass',
                '::Test::NotExists::Test1',
                '::SomeExternalClass',
                '::Superclass',
                '::SomeClass1',
                '::SomeClass2'
            )

  end
  it 'extract consts from code2 correctly' do
    consts = Ripper.extract_constants(code2)
    expect(consts[:declared].flatten).to include(
                '::Test::App2'
            )

    expect(consts[:used].flatten).to include(
                '::Test::Mount2',
                '::Test::Mount10',
                '::Test::SomeAnotherEntity',
                '::SomeClass',
                '::TopLevel'
            )

  end
end