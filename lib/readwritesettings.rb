require "yaml"
require "erb"
require 'open-uri'

# A simple settings solution using a YAML file. See README for more information.
class ReadWriteSettings < Hash
  class MissingSetting < StandardError; end

  class << self
    def name # :nodoc:
      self.superclass != Hash && instance.key?("name") ? instance.name : super
    end
        
    # Enables Settings.get('nested.key.name') for dynamic access
    def get(key)
      parts = key.split('.')
      curs = self
      while p = parts.shift
        curs = curs.send(p)
      end
      curs
    end

    def source(value = nil)
      @source ||= value
    end

    def namespace(value = nil)
      @namespace ||= value
    end

    def suppress_errors(value = nil)
      @suppress_errors ||= value
    end

    def [](key)
      instance.fetch(key.to_s, nil)
    end

    def []=(key, val)
      # Setting[:key][:key2] = 'value' for dynamic settings
      val = new(val, source) if val.is_a? Hash
      instance.store(key.to_s, val)
      instance.create_accessor_for(key, val)
    end

    def load!
      instance
      true
    end

    def reload!
      @instance = nil
      load!
    end

    private
      def instance
        return @instance if @instance
        @instance = new
        create_accessors!
        @instance
      end

      def method_missing(name, *args, &block)
        instance.send(name, *args, &block)
      end

      # It would be great to DRY this up somehow, someday, but it's difficult because
      # of the singleton pattern.  Basically this proxies Setting.foo to Setting.instance.foo
      def create_accessors!
        instance.each do |key,val|
          create_accessor_for(key)
        end
      end

      def create_accessor_for(key)
        return unless key.to_s =~ /^\w+$/  # could have "some-setting:" which blows up eval
        instance_eval "def #{key}; instance.send(:#{key}); end"
      end

  end

  # Initializes a new settings object. You can initialize an object in any of the following ways:
  #
  #   Settings.new(:application) # will look for config/application.yml
  #   Settings.new("application.yaml") # will look for application.yaml
  #   Settings.new("/var/configs/application.yml") # will look for /var/configs/application.yml
  #   Settings.new(:config1 => 1, :config2 => 2)
  #
  # Basically if you pass a symbol it will look for that file in the configs directory of your rails app,
  # if you are using this in rails. If you pass a string it should be an absolute path to your settings file.
  # Then you can pass a hash, and it just allows you to access the hash via methods.
  def initialize(hash_or_file = self.class.source, section = nil)
    #puts "new! #{hash_or_file}"
    case hash_or_file
    when nil
      raise Errno::ENOENT, "No file specified as ReadWriteSettings source"
    when Hash
      self.replace hash_or_file
    else
      file_contents = open(hash_or_file).read
      hash = file_contents.empty? ? {} : YAML.load(ERB.new(file_contents).result).to_hash
      if self.class.namespace
        hash = hash[self.class.namespace] or return missing_key("Missing setting '#{self.class.namespace}' in #{hash_or_file}")
      end
      self.replace hash
    end
    @section = section || self.class.source  # so end of error says "in application.yml"
    create_accessors!
  end

  # Called for dynamically-defined keys, and also the first key deferenced at the top-level, if load! is not used.
  # Otherwise, create_accessors! (called by new) will have created actual methods for each key.
  def method_missing(name, *args, &block)
    key = name.to_s
    return missing_key("Missing setting '#{key}' in #{@section}") unless has_key? key
    value = fetch(key)
    create_accessor_for(key)
    value.is_a?(Hash) ? self.class.new(value, "'#{key}' section in #{@section}") : value
  end

  def [](key)
    fetch(key.to_s, nil)
  end

  def []=(key,val)
    # Setting[:key][:key2] = 'value' for dynamic settings
    val = self.class.new(val, @section) if val.is_a? Hash
    store(key.to_s, val)
    create_accessor_for(key, val)
  end

  # Create a nested structure and set value.
  # For example: set("foo.bar.tar", 123)
  # Resulting ReadWriteSettings/Hash:
  # { "foo" => { "bar" => { "tar" => 123 }}}
  def set(nested_key, val)
    target_settings_field = self
    settings_key_portions = nested_key.to_s.split(".")
    parent_key_portions, final_key = settings_key_portions[0..-2], settings_key_portions[-1]
    parent_key_portions.each do |key_portion|
      target_settings_field[key_portion] ||= ReadWriteSettings.new({})
      target_settings_field = target_settings_field[key_portion]
    end
    target_settings_field[final_key] = val
    create_accessors!
  end

  # Like #set, but only sets the value if the key is not already set
  # Returns the existing value or the newly-set default value
  def set_default(nested_key, val)
    target_settings_field = self
    settings_key_portions = nested_key.to_s.split(".")
    parent_key_portions, final_key = settings_key_portions[0..-2], settings_key_portions[-1]
    parent_key_portions.each do |key_portion|
      target_settings_field[key_portion] ||= ReadWriteSettings.new({})
      target_settings_field = target_settings_field[key_portion]
    end
    target_settings_field[final_key] ||= val
    target_settings_field[final_key]
  end

  def nested_value(nested_key)
    target_settings_field = self
    settings_key_portions = nested_key.to_s.split(".")
    parent_key_portions, final_key = settings_key_portions[0..-2], settings_key_portions[-1]
    parent_key_portions.each do |key_portion|
      target_settings_field[key_portion] ||= ReadWriteSettings.new({})
      target_settings_field = target_settings_field[key_portion]
    end
    target_settings_field[final_key]
  end
  alias :exists? :nested_value

  # Returns an instance of a Hash object
  def to_hash
    Hash[self]
  end

  # Convert all nested ReadWriteSettings objects to Hash objects
  def to_nested_hash
    inject({}) do |hash, key_value|
      key, value = key_value
      hash[key]  = value.respond_to?(:to_nested_hash) ? value.to_nested_hash : value
      hash
    end
  end

  def save(path)
    File.open(path, "w") { |f| f << to_nested_hash.to_yaml }
  end

  # This handles naming collisions with Sinatra/Vlad/Capistrano. Since these use a set()
  # helper that defines methods in Object, ANY method_missing ANYWHERE picks up the Vlad/Sinatra
  # settings!  So settings.deploy_to title actually calls Object.deploy_to (from set :deploy_to, "host"),
  # rather than the app_yml['deploy_to'] hash.  Jeezus.
  def create_accessors!
    self.each do |key,val|
      create_accessor_for(key)
    end
  end

  # Use instance_eval/class_eval because they're actually more efficient than define_method{}
  # http://stackoverflow.com/questions/185947/ruby-definemethod-vs-def
  # http://bmorearty.wordpress.com/2009/01/09/fun-with-rubys-instance_eval-and-class_eval/
  def create_accessor_for(key, val=nil)
    return unless key.to_s =~ /^\w+$/  # could have "some-setting:" which blows up eval
    instance_variable_set("@#{key}", val)
    self.class.class_eval <<-EndEval
      def #{key}
        return @#{key} if @#{key}
        return missing_key("Missing setting '#{key}' in #{@section}") unless has_key? '#{key}'
        value = fetch('#{key}')
        @#{key} = if value.is_a?(Hash)
          self.class.new(value, "'#{key}' section in #{@section}")
        elsif value.is_a?(Array) && value.all?{|v| v.is_a? Hash}
          value.map{|v| self.class.new(v)}
        else
          value
        end
      end
    EndEval
  end
  
  def symbolize_keys
    
    inject({}) do |memo, tuple|
      
      k = (tuple.first.to_sym rescue tuple.first) || tuple.first
            
      v = k.is_a?(Symbol) ? send(k) : tuple.last # make sure the value is accessed the same way Settings.foo.bar works
      
      memo[k] = v && v.respond_to?(:symbolize_keys) ? v.symbolize_keys : v #recurse for nested hashes
      
      memo
    end
    
  end
  
  def missing_key(msg)
    return nil if self.class.suppress_errors

    raise MissingSetting, msg
  end
end
