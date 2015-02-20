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
    test_class_method({params: SomeClass})

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
    module EmptyModule
    end
  end
  class WithoutModule
    def use_top_level
      TopLevel.new
    end
    def self.method
      SomeModule::ShouldntUse.call
    end
  end
CODE
  }

  let!(:deeply_nested) {
    <<CODE
  module Test
    module Subtest
      class App2 < Grape::API
      end
    end
  end
CODE
  }

  # Sequel-related
  let!(:class_reference_with_call) {
    <<CODE
    module Test
      module Subtest
        class App2 < Grape::API(:test)
        end
      end
    end
CODE
  }

  let!(:grape_desc_args) {
    <<CODE
    module Test
      class App < Grape::API
        group do
          desc 'Blablabla',
            entity: [Test::SomeAnotherEntity]
          get :test do
            SomeClass.usage
            'test2 response'
          end
        end
      end
    end
CODE
  }

  let!(:class_level_call_with_args) {
    <<CODE
    module Test
      class TestClass
        UseModule::UseClass.call(arg)
      end
    end
CODE
  }

  let!(:lambda_class_usage) {
    <<CODE
    some_method ->(arg) {
      ModuleName::ClassName.call(arg)
    }
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
                '::Superclass'
            )

    expect(consts[:used].flatten).not_to include(
                                         '::SomeClass1',
                                         '::SomeClass2'
                                     )


  end
  it 'extract consts from code2 correctly' do
    consts = Ripper.extract_constants(code2)
    expect(consts[:declared].flatten).to include(
                '::Test::App2',
                '::Test::EmptyModule'
            )

    expect(consts[:used].flatten).to include(
                '::Test::Mount2',
                '::Test::Mount10',
                '::Test::SomeAnotherEntity',
            )

    expect(consts[:used].flatten).not_to include(
                                             '::SomeClass',
                                             '::TopLevel'
                                         )

  end

  it 'extracts consts used in deeply nested modules up to root namespace' do
    consts = Ripper.extract_constants(deeply_nested)
    expect(consts[:used].flatten).to include('::Grape::API')
  end

  it 'extracts const with call (sequel-related)' do
    consts = Ripper.extract_constants(class_reference_with_call)
    expect(consts[:used].flatten).to include('::Grape::API')
  end

  it 'extracts consts from desc method args' do
    consts = Ripper.extract_constants(grape_desc_args)
    expect(consts[:used].flatten).to include('::Test::SomeAnotherEntity')
  end

  it 'does not mess up class name when class level method called with argument' do
    consts = Ripper.extract_constants(class_level_call_with_args)
    expect(consts[:used].flatten).to include('::UseModule::UseClass')
  end

  it 'does not include classes used in lambdas' do
    consts = Ripper.extract_constants(lambda_class_usage)
    expect(consts[:used].flatten).not_to include('::ModuleName::ClassName')
  end
end