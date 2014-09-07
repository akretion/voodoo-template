# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

ENV['VAGRANT_DEFAULT_PROVIDER'] ||= 'docker'

COMMAND = ENV['CMD'] || 'up'
ODOO_DIR = ENV['ODOO_DIR']
EGGS_DIR = ENV['EGGS_DIR']

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define "voodoo" do |voodoo|
    volumes = ['/vagrant:/workspace']
    voodoo.vm.synced_folder ".", "/workspace", owner: 'developer', group: 'developer'

    # TODO parse buildout.dev.cfg in Ruby like ak instead of using env vars
    if ODOO_DIR
      voodoo.vm.synced_folder ODOO_DIR, "/odoo", owner: 'developer', group: 'developer'
      volumes += ["#{ODOO_DIR}:/.devstep/addons/voodoo/odoo"]
    end

    if EGGS_DIR
      voodoo.vm.synced_folder EGGS_DIR, "/eggs", owner: 'developer', group: 'developer'
      volumes += ["#{EGGS_DIR}:'/.devstep/addons/voodoo/host_eggs"]
    end

    voodoo.vm.provider "docker" do |d|
      d.image = "akretion/voodoo"
      d.name  = "voodoo"
      d.create_args     = ['-i', '-t', '--rm=true', '-w', '/workspace']
      d.cmd             = ['/workspace/ak'] + COMMAND.split(' ')
      d.has_ssh         = false
      d.remains_running = false
      d.ports           = ['8069:8069', '8072:8072']
      d.volumes         = volumes
    end
  end

end
