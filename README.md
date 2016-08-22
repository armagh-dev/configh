= Introduction =

This ruby library is yet another configuration data management tool. 
You could use an ORM / MVC system like rails to maintain configuration 
data records, but if you're for something very light-weight, this may
be a good choice.

* define the configuration parameters you need in your modules and classes 
* set values "manually" in your code (very useful for testing), from a json-/html-
  compatible API, or loaded from a persistent store
* guarantee saved configurations are always valid through the application of
  parameter-level type-checking and defaults, as well as your own custom validators
* persist configurations in the background via mongo
* extend the datatypes you can assign to parameters

(= Requirements =

This gem has been tested on Ruby 2.3.

Integration tests require that mongod and mongo be installed on the local machine.
)

== External Deps ==

Gems:
* mongo (2.2+)
* bundler

== Standard Library Deps ==

* date
* time
* securerandom

= Installation =

Within Noragh, the gem is available on our local server.
 
Externally, in the root directory of configh:
* bundle install
* PRODUCTION_RELEASE=true gem build config.gemspec
* gem install configh-*.gem --local

= Tests =
 
= More Information =

== API Documentation ==

See the doc directory.

= Example Usage = 

See the examples/ directory.
  
(= License =


)
    
    
