Dir[File.dirname(__FILE__) + "/gcm_client/*.rb"].each do |file|
  require file
end
