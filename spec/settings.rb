class Settings < ReadWriteSettings
  source "#{File.dirname(__FILE__)}/settings.yml"
end

class SettingsInst < ReadWriteSettings
end