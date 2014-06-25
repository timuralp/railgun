Dir[File.join(File.dirname(__FILE__), 'railgun/*.rb')].each {|f| require f}

module Railgun
  def new(options = {})
    Railgun::Client.new(options)
  end
end
