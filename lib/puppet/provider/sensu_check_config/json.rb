require 'json' if Puppet.features.json?
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..',
                                   'puppet_x', 'sensu', 'provider_create.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..',
                                   'puppet_x', 'sensu', 'fspaths.rb'))

Puppet::Type.type(:sensu_check_config).provide(:json) do
  confine :feature => :json

  # For testing purposes, provide access to @property_flush
  attr_reader :property_flush, :property_hash

  # Use Puppet standard getter and setter methods into @property_hash for all
  # type properties.  This is distinct from the resource object which contains
  # the desired state of the system from the DSL.
  #
  #The @property_hash contains the _current state_ of the system.  The
  #@property_flush hash contains the full Hash to be written back out to disk in
  #one write operation in the [flush] method.
  #
  # See: http://garylarizza.com/blog/2013/12/15/seriously-what-is-this-provider-doing/
  #
  # N.B. getter methods will return `:absent` for properties that do not have a
  # key in the @property_hash.  This is distinct from a key with a nil value,
  # which is an error.
  mk_resource_methods

  # Override the setter method created by mk_resource_methods.  Store the
  # desired value in @property_flush to be written in one write operation in the
  # [flush] method. The structure of @property_flush is what will be written as
  # JSON to the target file.
  def config=(should_value)
    @property_flush[name] = should_value
  end

  # Override the setter method created by mk_resource_methods.  Store the
  # desired value in @property_flush to be written in one write operation in the
  # [flush] method. The structure of @property_flush is what will be written as
  # JSON to the target file.
  def event=(should_value)
    if Hash === @property_flush['checks']
      @property_flush['checks'].merge!(should_value)
    else
      @property_flush['checks'] = {name => should_value}
    end
  end

  # Return an array of provider instances, instantiated with the current state
  # of the system.
  #
  # @return [Array<Puppet::Type::Provider>]
  def self.instances
    Dir["#{PuppetX::Sensu::Fspaths.conf_d}/checks/config_*.json"].map do |f|
      name = File.basename(f,File.extname(f))
      name.slice!('config_')
      data = load_json(f)
      rsrc_hash = {name: name, ensure: :present}
      if checks = data['checks']
        rsrc_hash[:event] = checks[name]
      end
      if config = data[name]
        rsrc_hash[:config] = config
      end

      new(rsrc_hash)
    end
  end

  # The prefetch class method is called once per run when Puppet encounters a
  # resource of that type in the catalog.  This method matches up resources from
  # the DSL with provider instances created with the instances class method.
  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  # Initialze the provider based on the state of the system provided via
  # [rsrc_hash].  Initializes @property_flush, used by the flush method to
  # modify the system state.
  #
  # @param [Hash] rsrc_hash A set of properties and values describing the
  # current state of the system.  This is most often provided by the instances
  # class method in the context of `puppet resource`.
  def initialize(rsrc_hash={})
    super(rsrc_hash)
    @property_flush = {}
  end

  def flush
    if @destroy
      File.unlink(config_file)
    else
      File.open(config_file, 'w') do |f|
        f.puts JSON.pretty_generate(@property_flush)
      end
    end
  end

  def create
    if event = resource[:event]
      self.event = event
    end
    if config = resource[:config]
      self.config = config
    end
  end

  # Signal the flush method
  def destroy
    @destroy = true
  end

  # The exists method looks at the property_hash, which is expected to be
  # initialized from any JSON existing on the filesystem at [config_file].
  def exists?
    @property_hash[:ensure] == :present
  end

  # return the configuration file path.
  #
  # @return [String] The full path to the target configuration file for this
  # resource.
  def config_file
    if resource
      bp = resource[:base_path]
    else
      bp = File.join(PuppetX::Sensu::Fspaths.conf_d, 'checks')
    end
    "#{bp}/config_#{name}.json"
  end

  # def config
  #   conf[resource[:name]]
  # end

  # def config=(value)
  #   conf[resource[:name]] = value
  # end

  # def event
  #   conf['checks'][resource[:name]]
  # end

  # def event=(value)
  #   conf['checks'][resource[:name]] = value
  # end

  # read_file exists to aid spec testing and provide a well-known spot to stub
  # out reading a file from the filesystem.
  #
  # @param [String] fpath the file to read, passed to File.read()
  #
  # @return [String] the data read, behaves the same as File.read() return value
  def self.read_file(fpath)
    File.read(fpath)
  end

  # see read_file class method
  def read_file(fpath)
    self.class.read_file(fpath)
  end

  # If the target JSON configuration file exists, load it, otherwise return nil
  #
  # @return [Hash, nil]
  def load_if_exists
    return nil if config_file == :absent
    self.class.load_json(config_file)
  end

  # Load JSON, if there are error return and empty JSON object, `{}`.  This is
  # common with an empty file, in which case we want everything written back
  # out.
  def self.load_json(fpath)
    data = read_file(fpath)
    begin
      JSON.parse(data)
    rescue JSON::ParserError => e
      Puppet.debug("Could not parse #{fpath} as JSON.  Using {}.  #{e.message}")
      {}
    end
  end
end
