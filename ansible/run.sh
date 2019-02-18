#!/bin/sh

# Install ansible rol to bootstrap coreos servers
ansible-galaxy install githubixx.etcd,7.0.0+3.2.24 -p ./roles

# Bootstrap all servers
ansible-playbook -i hosts main.yml
