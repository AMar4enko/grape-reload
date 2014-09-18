require 'grape'
require 'spec_helper'

describe Grape::Reload::DependencyMap do
  let!(:file_class_map) {
    {
        'file1' => {
            declared: ['::Class1'],
            used: [],
        },
        'file2' => {
            declared: ['::Class2'],
            used: ['::Class1','::Class3'],
        },
        'file3' => {
            declared: ['::Class3'],
            used: ['::Class2'],
        },
    }
  }
  let!(:dm) { Grape::Reload::DependencyMap.new([]) }

  it 'resolves dependent classes properly' do
    allow(dm).to receive(:map).and_return(file_class_map)
    # map = instance_double(Grape::Reload::DependencyMap)
    # allow(map).to receive(:map).and_return(file_class_map)

    expect(dm.dependent_classes('file1')).to include('::Class2','::Class3')
  end
end