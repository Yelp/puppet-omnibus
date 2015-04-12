# NOTE: This file is maintained in the puppet-omnibus package, NOT by puppet
#
# a config.ru, for use with every rack-compatible webserver.
# SSL needs to be handled outside this, though.

# if puppet is not in your RUBYLIB:
# $:.unshift('/opt/puppet/lib')
require '/opt/puppet-omnibus/var/lib/ruby/seppuku_patch.rb'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

$0 = "master"

# if you want debugging:
# ARGV << "--debug"

ARGV << "--rack"
ARGV << "--confdir" << "/etc/puppetmaster"
ARGV << "--vardir" << "/var/lib/puppetmaster"

require 'puppet/util/command_line'

class EnvironmentMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    ENV['HTTP_X_FORWARDED_FOR'] = env['HTTP_X_FORWARDED_FOR']
    @app.call(env)
  end
end

use EnvironmentMiddleware
run Puppet::Util::CommandLine.new.execute
