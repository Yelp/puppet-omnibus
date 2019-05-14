Omnibus Puppet package project
==============================

This is an Omnibus project that will build a "monolithic" OS package for Puppet.
It installs a source-built Ruby in /opt/puppet-omnibus, then installs all the
gems required for Puppet to work into this Ruby. This means it leaves the
system-supplied Ruby completely untouched, along with any other Rubies you might
happen to have installed.

Why create a monolithic Puppet package?
---------------------------------------

The goal was to create a Puppet package that could be dropped onto a system at
the end of the OS install and immediately begin to manage the system in its
entirety, which includes installing and managing the Ruby versions on the
machine. Keeping Puppet separate from Rubies used to run applications means this
is possible (and it also means you can't break your config management agent by
mucking around with Ruby).

What are Omnibus packages?
--------------------------

[Omnibus](https://github.com/opscode/omnibus-ruby) is an OS packaging system
built in Ruby, written by the Opscode folks. It was created to build monolithic
packages for Chef (which requires Ruby as well). Rather than re-inventing the
packaging wheel, it makes use of Jordan Sissel's

[fpm](https://github.com/jordansissel/fpm) to build the final package.

The first version of this project used Opscode's tool, but they didn't seem to
take pull requests, so I enhanced bernd's superb
[fpm-cookery](https://github.com/bernd/fpm-cookery) to create Omnibus packages,
and switched this project to use it.

Runtime OS package dependencies
-------------------------------

Obviously some components of Ruby/Puppet/Facter have library dependencies.
Opscode take the approach of building *any* binary component from source and
having it inside the package. I think this is wasteful if you only have a few OS
dependencies - instead, the final package this project builds depends on the OS
packages, so apt/yum will automatically pull them in when you install the
package.

The exception is libyaml, which now gets built into the Omnibus; this is to help
support RHEL/Centos etc without needing EPEL.

Available builds
----------------

The following gems are built:
- aws-sdk
- deep\_merge
- facter
- fog
- gpgme
- hiera
- json\_pure
- msgpack
- puppet
- rgen
- ruby-augeas
- ruby-shadow
- serverspec
- unicorn

Package contents
----------------

Besides Ruby and associated gems, the package also places scripts to run the
puppet, facter and hiera binaries in `/usr/bin` using `update-alternatives`. It
deploys an appropriate init script based on the official Puppetlabs script,
config files, and files in `/etc/default` / `/etc/sysconfig`.

How do I build the package?
---------------------------

You need to clone the repository and bundle it:

    $ git clone https://github.com/bobtfish/puppet-omnibus

Build process is relying heavily on Docker now since we need to build the
package for many different distribs. To build an Ubuntu Bionic package use:

    $ rake package_bionic

this will prepare (and store with a checksum) a Docker image for Bionic and
run the build process. The resulting package will be under `dist/`.

Build process reference
-----------------------

There are many tools in use here, here's a quick list:

- make (Makefile) - used by jenkins, provides itest\_$package entrypoints
- rake (Rakefile) - used to compile docker images and initiate package building
- rocker.rb (Rockerfile) - used to generate Dockerfiles for different distribs
- fpm (recipe.rb, puppet.rb, etc) - actual building and generating debs/rpms

How things look from Jenkins point of view
------------------------------------------

- make itest\_bionic
  - rake itest\_bionic
    - invoke package\_bionic
      - generate Dockerfile
      - invoke docker\_bionic if image for Dockerfile checksum doesnt exist
        - build docker image
        - install ruby 2.1.2 inside docker image
        - if all is good - tag image with Dockerfile checksum
      - run JENKINS_BUILD.sh inside prepared docker image
        - build puppet gem from github.com/Yelp/puppet.git fork
        - bundle gems needed for fpm and run fpm
        - move built package to dest folder
    - run itest script against new package in docker

Build troubleshooting
---------------------

Hardy docker images have outdated git (1.5) which doesn't support describe
command which is essential to building puppet gem of a correct version. This
is worked-around by building gem in specially named folder /tmp/puppet.3-6-2.

Bundler is stupid. Because of that puppet.rb recipe runs a script that
changes all shebangs in ruby scripts in `/opt/puppet-omnibus/embedded/bin` to
`#!/opt/puppet-omnibus/embedded/bin/ruby`.

Configuration
-------------

Unicorn server can be configured via following env variables:

- `PUPPET_OMNIBUS_LOG` (`/var/log/puppetmaster`) where unicorn logs go
- `PUPPET_OMNIBUS_WORKERS` (`12`) number of workers
- `PUPPET_OMNIBUS_WMLIMIT` (`500_000`) memory limit for worker process in Kilobytes
- `PUPPET_OMNIBUS_WRLIMIT` (`1000`) maximum number of requests worker can process

Testing
-------

I use this in production with Ubuntu 18.04, 16.04, and 14.04.
[beddari](https://github.com/beddari) reports it working on Fedora, CentOS and
RHEL.

Credits
-------

Credit for the Omnibus idea goes to the [Opscode](www.opscode.com) and
[Sensu](http://sensuapp.org/) folks. Credit for coming up with the idea of
packaging Puppet like Chef belongs to my colleague
[lloydpick](https://github.com/lloydpick). Thanks to
[bernd](https://github.com/bernd) for the
awesome [fpm-cookery](https://github.com/bernd/fpm-cookery) and for taking my
PRs. Thanks to [beddari](https://github.com/beddari) for his PRs to support RHEL
derivatives, and his almost complete overhaul of the project.
