require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

describe "ReadWriteSettings" do
  it "should access settings" do
    Settings.setting2.should == 5
  end
  
  it "should access nested settings" do
    Settings.setting1.setting1_child.should == "saweet"
  end
  
  it "should access settings in nested arrays" do
    Settings.array.first.name.should == "first"
  end

  it "should access deep nested settings" do
    Settings.setting1.deep.another.should == "my value"
  end

  it "should access extra deep nested settings" do
    Settings.setting1.deep.child.value.should == 2
  end

  it "should enable erb" do
    Settings.setting3.should == 25
  end

  it "should namespace settings" do
    Settings2.setting1_child.should == "saweet"
    Settings2.deep.another.should == "my value"
  end

  it "should return the namespace" do
    Settings.namespace.should be_nil
    Settings2.namespace.should == 'setting1'
  end

  it "should distinguish nested keys" do
    Settings.language.haskell.paradigm.should == 'functional'
    Settings.language.smalltalk.paradigm.should == 'object oriented'
  end
  
  it "should not collide with global methods" do
    Settings3.nested.collides.does.should == 'not either'
    Settings3[:nested] = 'fooey'
    Settings3[:nested].should == 'fooey'
    Settings3.nested.should == 'fooey'
    Settings3.collides.does.should == 'not'
  end

  it "should raise a helpful error message" do
    e = nil
    begin
      Settings.missing
    rescue => e
      e.should be_kind_of ReadWriteSettings::MissingSetting
    end
    e.should_not be_nil
    e.message.should =~ /Missing setting 'missing' in/

    e = nil
    begin
      Settings.language.missing
    rescue => e
      e.should be_kind_of ReadWriteSettings::MissingSetting
    end
    e.should_not be_nil
    e.message.should =~ /Missing setting 'missing' in 'language' section/
  end

  it "should handle optional / dynamic settings" do
    e = nil
    begin
      Settings.language.erlang
    rescue => e
      e.should be_kind_of ReadWriteSettings::MissingSetting
    end
    e.should_not be_nil
    e.message.should =~ /Missing setting 'erlang' in 'language' section/
    
    Settings.language['erlang'].should be_nil
    Settings.language['erlang'] = 5
    Settings.language['erlang'].should == 5

    Settings.language['erlang'] = {'paradigm' => 'functional'}
    Settings.language.erlang.paradigm.should == 'functional'
    Settings.respond_to?('erlang').should be_false

    Settings.reload!
    Settings.language['erlang'].should be_nil

    Settings.language[:erlang] ||= 5
    Settings.language[:erlang].should == 5

    Settings.language[:erlang] = {}
    Settings.language[:erlang][:paradigm] = 'functional'
    Settings.language.erlang.paradigm.should == 'functional'

    Settings[:toplevel] = '42'
    Settings.toplevel.should == '42'
  end

  it "should raise an error on a nil source argument" do
    class NoSource < ReadWriteSettings; end
    e = nil
    begin
      NoSource.foo.bar
    rescue => e
      e.should be_kind_of Errno::ENOENT
    end
    e.should_not be_nil
  end

  it "should allow suppressing errors" do
    Settings4.non_existent_key.should be_nil
  end

  # This one edge case currently does not pass, because it requires very
  # esoteric code in order to make it pass.  It was judged not worth fixing,
  # as it introduces significant complexity for minor gain.
  # it "should handle reloading top-level settings"
  #   Settings[:inspect] = 'yeah baby'
  #   Settings.inspect.should == 'yeah baby'
  #   Settings.reload!
  #   Settings.inspect.should == 'Settings'
  # end

  it "should handle oddly-named settings" do
    Settings.language['some-dash-setting#'] = 'dashtastic'
    Settings.language['some-dash-setting#'].should == 'dashtastic'
  end

  it "should handle settings with nil value" do
    Settings["flag"] = true
    Settings["flag"] = nil
    Settings.flag.should == nil
  end

  it "should handle settings with false value" do
    Settings["flag"] = true
    Settings["flag"] = false
    Settings.flag.should == false
  end

  it "should support instance usage as well" do
    settings = SettingsInst.new(Settings.source)
    settings.setting1.setting1_child.should == "saweet"
  end

  it "should be able to get() a key with dot.notation" do
    Settings.get('setting1.setting1_child').should == "saweet"
    Settings.get('setting1.deep.another').should == "my value"
    Settings.get('setting1.deep.child.value').should == 2
  end

  # If .name is not a property, delegate to superclass
  it "should respond with Module.name" do
    Settings2.name.should == "Settings2"
  end

  # If .name is called on ReadWriteSettings itself, handle appropriately
  # by delegating to Hash
  it "should have the parent class always respond with Module.name" do
    ReadWriteSettings.name.should == 'ReadWriteSettings'
  end

  # If .name is a property, respond with that instead of delegating to superclass
  it "should allow a name setting to be overriden" do
    Settings.name.should == 'test'
  end
  
  it "should allow symbolize_keys" do
    Settings.reload!
    result = Settings.language.haskell.symbolize_keys 
    result.class.should == Hash
    result.should == {:paradigm => "functional"} 
  end
  
  it "should allow symbolize_keys on nested hashes" do
    Settings.reload!
    result = Settings.language.symbolize_keys
    result.class.should == Hash
    result.should == {
      :haskell => {:paradigm => "functional"},
      :smalltalk => {:paradigm => "object oriented"}
    }
  end

  it "should handle empty file" do
    SettingsEmpty.keys.should eql([])
  end

  # Put this test last or else call to .instance will load @instance,
  # masking bugs.
  it "should be a hash" do
    Settings.send(:instance).should be_is_a(Hash)
  end

  describe "#to_hash" do
    it "should return a new instance of a Hash object" do
      Settings.to_hash.should be_kind_of(Hash)
      Settings.to_hash.class.name.should == "Hash"
      Settings.to_hash.object_id.should_not == Settings.object_id
    end
  end

  describe "#to_nested_hash" do
    it "should convert all nested ReadWriteSettings objects to Hash objects" do
      hash = Settings.to_nested_hash
      hash.class.should == Hash
      hash["language"].class.should == Hash
      hash["language"]["haskell"].class.should == Hash
      hash["language"]["haskell"]["paradigm"].class.should == String
    end
  end

  describe "#save(file)" do
    it "should save ReadWriteSettings object such that it can be reloaded later" do
      Settings.reload!
      Settings["extra"] = {}
      Settings["extra"]["value"] = 123
      Settings.extra.value.should == 123
      Settings.save("/tmp/settings.yml")

      later_on = ReadWriteSettings.new("/tmp/settings.yml")
      later_on.extra.value.should == 123
    end
  end

  describe "#set('nested.key', value)" do
    it "works like []= for non-dotted keys" do
      Settings.set("simple", "value")
      Settings.simple.should == "value"
    end

    it "creates new nested structures" do
      Settings.set("nested.key", "value")
      Settings.nested.key.should == "value"
    end

    it "reuses existing structures" do
      Settings.set("language.ruby.paradigm", "scripting")
      Settings.language.haskell.paradigm.should == "functional"
      Settings.language.ruby.paradigm.should == "scripting"
    end
  end

  describe "#set_default('nested.key', value)" do
    it "works like #set if key 'nested.key' missing" do
      Settings.set("nested", {})
      Settings.set_default("nested.key", "default").should == "default"
      Settings.nested.key.should == "default"
    end

    it "works like #set if key 'nested' missing" do
      Settings.set_default("nested.key", "default").should == "default"
      Settings.nested.key.should == "default"
    end

    it "does nothing if nested.key is set" do
      Settings.set("nested.key", "value")
      Settings.set_default("nested.key", "default").should == "value"
      Settings.nested.key.should == "value"
    end
  end

  describe "#exists?('nested.key') && #value('nested.key')" do
    before { Settings.reload! }
    it "returns truthy if nested.key is set" do
      Settings.set("nested.key", "value")
      Settings.nested_value("nested.key").should == "value"
    end

    it "returns falsy if nested is not set" do
      Settings.nested_value("nested.key").should be_nil
    end

    it "returns falsy if nested.key is not set" do
      Settings.set("nested", {})
      Settings.exists?("nested.key").should be_nil
    end
  end

end
