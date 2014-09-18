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

    builder = Grape::RackBuilder.setup do
        logger Logger.new(STDOUT)
        add_source_path File.expand_path('**/*.rb', YOUR_APP_ROOT)
        reload_threshold 1 # Reload sources not often one second
        mount 'Your::App', to: '/'
        mount 'Your::App1', to: '/app1'
    end

    run builder

Grape::Reload will resolve all class dependencies and load your files in appropriate order, so you don't need to include 'require' or 'require_relative' for your app classes.

## Restrictions:

If you want to monkey-patch class in your code for any reason, you should use 
    
    AlreadyDefined.class_eval do 
    end

instead of

    class AlreadyDefined
    end  

because it confuses dependency resolver

## Known issues

* It still lacks of good design :(  
* MOAR TESTS!!!!111

## Contributing

1. Fork it ( https://github.com/AMar4enko/grape-reload/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
