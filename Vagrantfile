# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<-SCRIPT
apt-get update
apt-get upgrade -y
apt-get install -y traceroute gobgpd quagga

SCRIPT

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/bionic64"
  config.vm.hostname = "bionic"
  config.vm.synced_folder "./data", "/vagrant_data"
  config.vm.provision "shell", inline: $script

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
  end

end
