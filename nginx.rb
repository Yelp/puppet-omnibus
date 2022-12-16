class Nginx < FPM::Cookery::Recipe
  description 'a high performance web server and a reverse proxy server'

  name     'nginx'
  version  '1.16.1'
  revision 1
  homepage 'http://nginx.org/'
  source   "http://nginx.org/download/nginx-#{version}.tar.gz"
  sha1     '77ce4d26481b62f7a9d83e399454df0912f01a4b'

  section 'System Environment/Daemons'

  build_depends 'make', 'gcc', 'g++', 'libxml2-dev', 'libxslt1-dev'

  rel = `cat /etc/lsb-release | grep DISTRIB_CODENAME | cut -d= -f2`.chomp
  case rel
  when 'xenial'
    build_depends 'libssl-dev'
    depends 'libssl1.0.0'
  when 'bionic'
    build_depends 'libssl1.0-dev'
    depends 'libssl1.0.0'
  else
    build_depends 'libssl-dev'
    depends 'libssl1.1'
  end
  depends 'libxml2', 'libxslt1.1'

  def build
    configure \
      '--with-http_stub_status_module',
      '--with-http_ssl_module',
      '--with-pcre',
      '--with-file-aio',
      '--with-http_realip_module',
      '--with-http_auth_request_module', # http://nginx.org/en/docs/http/ngx_http_auth_request_module.html

      '--without-http_scgi_module',
      '--without-http_uwsgi_module',
      '--without-http_fastcgi_module',

      :prefix                     => prefix,

      :user                       => 'puppet',
      :group                      => 'puppet',

      :pid_path                   => '/var/run/puppetmaster-nginx.pid',
      :lock_path                  => '/var/lock/puppetmaster-nginx',
      :conf_path                  => '/opt/puppet-omnibus/etc/nginx.conf',
      :http_log_path              => '/var/log/puppetmaster/nginx-access.log',
      :error_log_path             => '/var/log/puppetmaster/nginx-error.log',
      :http_proxy_temp_path       => '/var/tmp/puppetmaster-proxy',
      :http_fastcgi_temp_path     => '/var/tmp/puppetmaster-fastcgi',
      :http_client_body_temp_path => '/var/tmp/puppetmaster-client_body'

    make '-s'
  end

  def install
    # server
    destdir('../etc').install workdir('nginx/nginx.conf')
    destdir('../bin').install workdir('shared/omnibus.bin'), 'nginx'
    destdir('bin').install Dir['objs/nginx']
  end
end
