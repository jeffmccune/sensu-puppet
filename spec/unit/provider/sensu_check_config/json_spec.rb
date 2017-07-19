require 'spec_helper'

# Terminology used in the let helper methods.
#
# "resource" is an instance of Puppet::Type.type(:sensu_check_config) as it
# would exist in the RAL during catalog application.  This resource contains the
# desired state information, the properties and parameters specified in the
# Puppet DSL.
#
# "provider" is an instance of the provider class being tested.  In Puppet,
# provider instances exist primarily in one of two states, either bound or not
# bound to a resource.  Provider instances are not bound when the system is
# being introspected, e.g. `puppet resource service` calls the `instances` class
# method which will instantiate provider instances which have no associated
# resource.  When applying a Puppet catalog, each provider is associated with
# exactly one resource from the Puppet DSL.
#
# Because of this dual nature, providers must be careful when accessing
# parameter data, e.g. `base_path`.  Since `base_path` is a parameter, it will
# not be accessible in the context of self.instances and `puppet resource`,
# because there is not a bound resource when discovering resources.
#
# When building a new provider with spec tests, start with `self.instances`,
# because this approach exercises a provider with the minimal amount of state.
# That is to say, the provider must be well-behaved when there is no associated
# resource.
#
# property_hash or @property_hash is an instance variable describing the current
# state of the resource as it exists on the target system.  Take care not to
# confuse this with the data contained in the resource, which describes desired
# state.
#
# property_flush or @property_flush is an instance variable used to modify the
# system from the `flush` method.  Setter methods, one for each property of the
# resource type, should modify @property_flush
describe Puppet::Type.type(:sensu_check_config).provider(:json) do
  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:type) { Puppet::Type.type(:sensu_check_config) }

  # The title of the resource, for convenience
  let(:title) { 'mycheck' }
  # The default resource hash modeling the resource in a manifest.
  let(:rsrc_hsh_base) do
    { name: title, ensure: 'present' }
  end
  # Override this helper method in nested example groups
  let(:rsrc_hsh_override) { {} }
  # Combined resource hash.  Used to initialize @provider_hash via new()
  let(:rsrc_hsh) { rsrc_hsh_base.merge(rsrc_hsh_override) }
  # A provider with @property_hash initialized, but without a resource.
  let(:bare_provider) { described_class.new(rsrc_hsh) }
  # A resource bound to bare_provider.  This has the side-effect of associating
  # the provider instance to a resource.
  let(:resource) { type.new(rsrc_hsh.merge(provider: bare_provider)) }
  # A "harnessed" provider instance suitable for testing.  @property_hash is
  # initialized and provider.resource returns resource.  That is, after
  # evaluating this block provider.resource and resource refer to the same
  # object.
  let(:provider) do
    resource.provider
  end

  # Example sensu check configuration.  Derived from
  # `/etc/sensu/conf.d/checks/check_ntp.json` in vagrant sensu-server
  let(:check_configuration) do
    {
      'command' => 'check_ntp_time -H pool.ntp.org -w 30 -c 60',
      'handlers' => ['default'],
      'interval' => 60,
      'standalone' => true,
      'subscribers' => ['sensu-test'],
    }
  end

  context 'during catalog application' do
    subject { provider }

    describe 'parameters (provide data)' do
      describe '#name' do
        subject { provider.name }
        it { is_expected.to eq title }
      end
    end

    # Properties do stuff to the system.  Parameters add supporting data.
    describe 'properties (do stuff)' do
      # TODO: Find an example of a valid "client config" in the context of a
      # sensu check.  I didn't see any at
      # https://sensuapp.org/docs/1.0/reference/checks.html#sensu-check-specification
      let(:client_config) { { 'foo' => 'bar' } }

      describe '#config' do
        subject { provider.config }
        context 'default' do
          it { is_expected.to eq(:absent) }
        end

        context 'when config => {"foo": "bar"}' do
          let(:rsrc_hsh_override) { {config: client_config} }
          it do
            is_expected.to eq(client_config) 
          end
        end
      end

      describe '#config=' do
        describe 'JSON object to be written by #flush' do
          subject { provider.property_flush }
          before(:each) { provider.config = client_config }
          it { is_expected.to eq({title => client_config}) }
        end
      end

      describe '#event' do
        subject { provider.event }

        context 'default' do
          it { is_expected.to eq(:absent) }
        end

        context 'when event => valid check event' do
          let(:rsrc_hsh_override) { {event: check_configuration} }
          it { is_expected.to eq(check_configuration) }
        end
      end
    end

    describe 'ensurable API methods' do
      describe '#pre_create'
      describe '#flush'
      describe '#destroy'
      describe '#exists?'
    end

    describe 'supporting helper methods' do
      fdescribe '#config_file' do
        subject { provider.config_file }
        context 'by default' do
          it do
            is_expected.to eq '/etc/sensu/conf.d/checks/config_mycheck.json'
          end
        end

        context 'when base_path is specified' do
          let(:rsrc_hsh_override) { { base_path: '/tmp/foo' } }
          it { is_expected.to eq '/tmp/foo/config_mycheck.json' }
        end

        context 'when name is specified' do
          let(:rsrc_hsh_override) { { name: 'my_other_check' } }
          it { is_expected.to eq '/etc/sensu/conf.d/checks/config_my_other_check.json' }
        end
      end
    end
  end
end
