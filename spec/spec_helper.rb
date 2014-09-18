require 'pry'
require 'grape/reload'
require 'rack'
require 'rack/test'
require 'grape'
require 'rspec/mocks'

APP_ROOT = File.expand_path('spec/fixtures')

module FileHelpers
  class FixtureChangesStorage
    def self.fixture_modified(file_name, original_content)
      modified_fixtures[file_name] = original_content
    end

    def self.revert_fixtures!
      modified_fixtures.each_pair do |file_name, content|
        revert_fixture(file_name)
      end
      @modified_fixtures = {}
    end

    def self.revert_fixture(file_name)
      return unless modified_fixtures[file_name]
      data = modified_fixtures.delete(file_name)
      File.write(file_name, data.last)
      File.utime(File.atime(file_name), data.first, file_name)
    end

    def self.modified_fixtures
      @modified_fixtures ||= {}
    end
  end

  def with_changed_fixture(file_name, &block)
    file_name = File.expand_path(file_name, APP_ROOT)
    lines = File.read(file_name).split("\n")
    new_lines = []
    lines.each do |l|
      if (/^(?<prepend>\s*).+\#\s?changed:\s?(?<changes>.+)/ =~ l).nil?
        new_lines << l
      else
        new_lines << prepend + changes
      end
    end
    File.write(file_name, new_lines.join("\n"))
    mtime = File.mtime(file_name)
    File.utime(File.atime(file_name), 1.day.from_now, file_name)
    FixtureChangesStorage.fixture_modified(file_name, [mtime, lines.join("\n")])
    yield if block_given?
    FixtureChangesStorage.revert_fixture(file_name)
  end
end

RSpec::Matchers.define :succeed do
  match do |actual|
    (actual.status == 200) || (actual.status == 201)
  end

  failure_message do |actual|
    "expected that #{actual} succeed, but got #{actual.status} error:\n#{actual.body}"
  end

  failure_message_when_negated do |actual|
    "expected that #{actual} fails, but got #{actual.status}"
  end

  description do
    'respond with 200 or 201 status code'
  end
end

RSpec.configure do |c|
  c.include FileHelpers
  c.include Rack::Test::Methods
  c.after(:suite) do |*args|
    FileHelpers::FixtureChangesStorage.revert_fixtures!
  end
end