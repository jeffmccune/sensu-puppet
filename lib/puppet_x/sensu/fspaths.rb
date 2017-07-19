module PuppetX
  module Sensu
    ##
    # Helper methods to provide a single place to define default values for
    # filesystem paths.  These methods are expected to be called from types and
    # providers, they exist because a provider may not be able to access the
    # path from a parameter passed to the resource type.  For example, when
    # introspecting the system with `puppet resource`, provider instances have
    # no associated resource.
    module Fspaths
      # The default etc directory.  On windows, 'C:/opt/sensu', on all other
      # platforms, '/etc/sensu'
      #
      # @return [String] the fully qualified path to the sensu etc directory.
      def self.etc_dir
        Puppet.features.microsoft_windows? ? 'C:/opt/sensu' : '/etc/sensu'
      end

      # The 'conf.d' sub-directory of etc_dir
      #
      # @return [String] the fully qualified path to the sensu conf.d directory.
      def self.conf_d
        File.join(etc_dir, 'conf.d')
      end
    end
  end
end
