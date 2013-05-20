class Settings2 < ReadWriteSettings
  source "#{File.dirname(__FILE__)}/settings.yml"
  namespace "setting1"
end