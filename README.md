[![Build Status](https://travis-ci.org/AlexYankee/grape-reload.svg?branch=master)](https://travis-ci.org/AlexYankee/grape-reload)
[![Gem Version](https://badge.fury.io/rb/grape-reload.svg)](http://badge.fury.io/rb/grape-reload)

# Grape::Reload

Expiremental approach for providing reloading of Grape-based rack applications in dev environment.  
It uses Ripper to extract class usage and definitions from code and reloads files and API classes based on dependency map.

## Installation

Add this line to your application's Gemfile:

    gem 'grape-reload'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install grape-reload

## Usage

In your config.ru you use Grape::RackBuilder to mount your apps:

```ruby
Grape::RackBuilder.setup do
    logger Logger.new(STDOUT)
    add_source_path File.expand_path('**/*.rb', YOUR_APP_ROOT)
    reload_threshold 1 # Reload sources not often one second
    force_reloading true # Force reloading for any environment (not just dev), useful for testing
    mount 'Your::App', to: '/'
    mount 'Your::App1', to: '/app1'
end

run Grape::RackBuilder.boot!.application
```

`Grape::Reload` will resolve all class dependencies and load your files in appropriate order, so you don't need to include 'require' or 'require_relative' in your sources.

## Restrictions

### Monkey patching

If you want to monkey-patch class in code, you want to be reloaded, for any reason, you should use

```ruby
AlreadyDefined.class_eval do 
end
```

instead of

```ruby
class AlreadyDefined
end
```

because it confuses the dependency resolver.

### Fully-qualified const name usage

Consider code

```ruby
require 'some_file' # (declares SomeModule::SomeClass)

here_is_your_code(SomeClass)
```

Ruby will resolve SomeClass to SomeModule::SomeClass in runtime.
Dependency resolver will display an error, because it expects you to
use full-qualified class name in this situation.
Anyway, it would not raise exception anymore (since e5b58f4)

```ruby
here_is_your_code(SomeModule::SomeClass)
```

### Other restrictions

Avoid declaring constants as follows

```ruby
class AlreadyDeclaredModule::MyClass
end
```

use

```ruby
module AlreadyDeclaredModule
    class MyClass
    end
end
```

instead

## Known issues

* It still lacks of good design :(  
* MOAR TESTS!!!!111

## TODO

* example Grape application with `Grape::Reload`
* Spork integration example

## Contributing

1. Fork it ( https://github.com/AlexYankee/grape-reload/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
