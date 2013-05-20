class Settings3 < ReadWriteSettings
  source "#{File.dirname(__FILE__)}/settings.yml"
  load!  # test of load
end