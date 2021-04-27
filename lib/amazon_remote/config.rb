module AmazonRemote

  def self.config
    @@config ||= AmazonRemote.new
  end

  def self.configure
    yield config if block_given?
  end

  class AmazonRemote 
    [:typical_amazon_delay, :username, :password, :download_dir ].each do |attr|
      attr_accessor attr
    end
  end
end



