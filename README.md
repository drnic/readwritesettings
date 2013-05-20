# ReadWriteSettings

ReadWriteSettings is a simple configuration / settings solution that uses an ERB enabled YAML file. It has been great for
our apps, maybe you will enjoy it too.  ReadWriteSettings works with Rails, Sinatra, or any Ruby project.

It is a fork of [ReadWriteSettings](http://github.com/binarylogic/settingslogic) to support modifications and additional getting/setter methods. Hopefully can merge this fork back into Settingslogic in future and have a single project again.

## Helpful links

* <b>Issues:</b> http://github.com/drnic/readwritesettings/issues
* <b>Source:</b> http://github.com/drnic/readwritesettings
* [![Build Status](https://travis-ci.org/drnic/readwritesettings.png?branch=master)](https://travis-ci.org/drnic/readwritesettings)
* [![Code Climate](https://codeclimate.com/github/drnic/readwritesettings.png)](https://codeclimate.com/github/drnic/readwritesettings)

## Installation

Add the following to your Gemfile:

``` ruby
gem "readwritesettings"
```

## Usage

### 1. Define your class

Instead of defining a Settings constant for you, that task is left to you. Simply create a class in your application
that looks like:

``` ruby
class Settings < ReadWriteSettings
  source "#{Rails.root}/config/application.yml"
  namespace Rails.env
end
```

Name it Settings, name it Config, name it whatever you want. Add as many or as few as you like. A good place to put
this file in a rails app is app/models/settings.rb

I felt adding a settings file in your app was more straightforward, less tricky, and more flexible.

Alternately, you can pass a Hash into the constructor.

``` ruby
Settings = ReadWriteSettings.new({"key" => "value"})
```

### 2. Create your settings

Notice above we specified an absolute path to our settings file called "application.yml". This is just a typical YAML file.
Also notice above that we specified a namespace for our environment.  A namespace is just an optional string that corresponds
to a key in the YAML file.

Using a namespace allows us to change our configuration depending on our environment:

``` yaml
# config/application.yml
defaults: &defaults
  cool:
    saweet: nested settings
  neat_setting: 24
  awesome_setting: <%= "Did you know 5 + 5 = #{5 + 5}?" %>

development:
  <<: *defaults
  neat_setting: 800

test:
  <<: *defaults

production:
  <<: *defaults
```

_Note_: Certain Ruby/Bundler versions include a version of the Psych YAML parser which incorrectly handles merges (the `<<` in the example above.)
If your default settings seem to be overwriting your environment-specific settings, including the following lines in your config/boot.rb file may solve the problem:

``` ruby
require 'yaml'
YAML::ENGINE.yamler= 'syck'
```

### 3. Access your settings

``` ruby
>> Rails.env
=> "development"

>> Settings.cool
=> "#<ReadWriteSettings::Settings ... >"

>> Settings.cool.saweet
=> "nested settings"

>> Settings.neat_setting
=> 800

>> Settings.awesome_setting
=> "Did you know 5 + 5 = 10?"
```

You can use these settings anywhere, for example in a model:

``` ruby
class Post < ActiveRecord::Base
  self.per_page = Settings.pagination.posts_per_page
end
```

You can also enquire about a nested setting. `exists?` returns the value or nil if the nested setting is set.

``` ruby
Settings.exists?("cool.sweet.thing")
```

### 4. Optional / dynamic settings

Often, you will want to handle defaults in your application logic itself, to reduce the number of settings
you need to put in your YAML file.  You can access an optional setting by using Hash notation:

``` ruby
>> Settings.messaging.queue_name
=> Exception: Missing setting 'queue_name' in 'message' section in 'application.yml'

>> Settings.messaging['queue_name']
=> nil

>> Settings.messaging['queue_name'] ||= 'user_mail'
=> "user_mail"

>> Settings.messaging.queue_name
=> "user_mail"
```

Modifying our model example:

``` ruby
class Post < ActiveRecord::Base
  self.per_page = Settings.posts['per_page'] || Settings.pagination.per_page
end
```

This would allow you to specify a custom value for per_page just for posts, or
to fall back to your default value if not specified.

### 5. Suppressing Exceptions Conditionally

Raising exceptions for missing settings helps highlight configuration problems.  However, in a
Rails app it may make sense to suppress this in production and return nil for missing settings.
While it's useful to stop and highlight an error in development or test environments, this is
often not the right answer for production.

``` ruby
class Settings < ReadWriteSettings
  source "#{Rails.root}/config/application.yml"
  namespace Rails.env
  suppress_errors Rails.env.production?
end

>> Settings.non_existent_key
=> nil
```

### 6. Changes and saving settings

In ReadWriteSettings v3.0+ (the fork of Settingslogic) there are more helpers for changing the settings and saving them back to disk.

``` ruby
settings = ReadWriteSettings.new({})
settings.set_default("some.interesting.default", "value")
settings
=> {"some"=>{"interesting"=>{"default"=>"value"}}} 

settings.set_default("some.interesting.default", "CHANGE")
settings
=> {"some"=>{"interesting"=>{"default"=>"value"}}} 

settings.set("some.interesting.default", "CHANGE")
settings
=> {"some"=>{"interesting"=>{"default"=>"CHANGE"}}} 

settings.save("/tmp/settings.yml")
ReadWriteSettings.new("/tmp/settings.yml")
=> {"some"=>{"interesting"=>{"default"=>"CHANGE"}}} 
```

## Note on Sinatra / Capistrano / Vlad

Each of these frameworks uses a +set+ convention for settings, which actually defines methods
in the global Object namespace:

``` ruby
set :application, "myapp"  # does "def application" globally
```

This can cause collisions with ReadWriteSettings, since those methods are global. Luckily, the
solution is to just add a call to load! in your class:

``` ruby
class Settings < ReadWriteSettings
  source "#{Rails.root}/config/application.yml"
  namespace Rails.env
  load!
end
```

It's probably always safest to add load! to your class, since this guarantees settings will be
loaded at that time, rather than lazily later via method_missing.

Finally, you can reload all your settings later as well:

``` ruby
Settings.reload!
```

This is useful if you want to support changing your settings YAML without restarting your app.

## History

This project was originally created by Ben Johnson and called Settingslogic. A renamed fork was created so that new gem versions could be released with new functionality, by Dr Nic Williams. The latter is not entirely thrilled about this situation; but at least he now has a versioned gem with the new shiny stuff in it.

Copyright (c) 2008-2010 [Ben Johnson](http://github.com/binarylogic) of [Binary Logic](http://www.binarylogic.com),
released under the MIT license.  Support for optional settings and reloading by [Nate Wiger](http://nate.wiger.org).

Copyright (c) 2013 [Dr Nic Williams](http://github.com/drnic)