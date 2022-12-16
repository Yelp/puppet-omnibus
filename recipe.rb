# TODO: fix this upstream
class FPM::Cookery::Path
  def encoding
    @encoding ||= Encoding.find("filesystem")
  end
end

class FPM::Cookery::Recipe
  alias :old_cachedir :cachedir
  def cachedir(*args)
    path = ENV['FPM_CACHE_DIR']
    path ? FPM::Cookery::Path.new(path) : old_cachedir(*args)
  end
end

class PuppetOmnibus < FPM::Cookery::Recipe
  homepage 'https://github.com/bobtfish/puppet-omnibus'
  section 'Utilities'
  name 'puppet-omnibus'
  version ENV['PUPPET_BASE']
  description 'Puppet Omnibus package'
  revision ENV['PKG_ITERATION']

  maintainer '<tdoran@yelp.com>'
  license 'Apache 2.0 License'

  source '', :with => :noop

  omnibus_package true
  omnibus_dir     "/opt/#{name}"
  omnibus_recipes 'libaugeas', 'puppet', 'nginx'

  conflicts(*%w{puppetmaster puppetmaster-passenger puppetmaster-common})

  rel = `cat /etc/lsb-release | grep DISTRIB_CODENAME | cut -d= -f2`.chomp
  case rel
  when 'xenial', 'bionic'
    depends 'libssl1.0.0'
  else
    depends 'libssl1.1'
  end

  def build
  end

  def install
    create_post_install_hook
    create_pre_uninstall_hook

    # Set paths to package scripts
    self.class.post_install builddir('post-install')
    self.class.pre_uninstall builddir('pre-uninstall')
  end

  BINS="puppet facter hiera"

  def create_post_install_hook
    File.open(builddir('post-install'), 'w', 0755) do |f|
      f.write <<-__POSTINST
#!/bin/sh
set -e

if [ "$1" = "configure" ]; then
    # Create the "puppet" user
    if ! getent passwd puppet > /dev/null; then
        adduser --quiet --system --group --home /var/lib/puppet  \
            --no-create-home                                 \
            --gecos "Puppet configuration management daemon" \
            puppet
    fi

    # Set correct permissions and ownership for puppet directories
    if ! dpkg-statoverride --list /var/log/puppet >/dev/null 2>&1; then
        dpkg-statoverride --update --add puppet puppet 0750 /var/log/puppet
    fi

    if ! dpkg-statoverride --list /var/lib/puppet >/dev/null 2>&1; then
        dpkg-statoverride --update --add puppet puppet 0750 /var/lib/puppet
    fi

    # Create folders common to "puppet" and "puppetmaster", which need
    # to be owned by the "puppet" user
    install --owner puppet --group puppet --directory \
        /var/lib/puppet/state
fi

BIN_PATH="#{destdir}/bin"
BINS="#{BINS}"

for BIN in $BINS; do
  update-alternatives --install /usr/bin/$BIN $BIN $BIN_PATH/$BIN 100
done

exit 0
      __POSTINST
    end
  end

  def create_pre_uninstall_hook
    File.open(builddir('pre-uninstall'), 'w', 0755) do |f|
      f.write <<-__PRERM
#!/bin/sh

BIN_PATH="#{destdir}/bin"
BINS="#{BINS}"

if [ "$1" != "upgrade" ]; then
  for BIN in $BINS; do
    update-alternatives --remove $BIN $BIN_PATH/$BIN
  done
fi

exit 0
      __PRERM
    end
  end
end
