# vim: tabstop=8 expandtab shiftwidth=2 softtabstop=2
#
# launch the screwdriver executor mounting volumes from screwdrivercd/launcher
#
# this file is used to create the wireline api call for nomad
# there is an issue with the datacenters, need to get that and the regions
# from outside somewhere.  for now, hard coded.
#
# and, we have a template to build a template, groovy, right?
# cd config
# ( unset VAULT_TOKEN jt nomad.hcl '{"dc":["rocklin","twinsburg","southlake","branchburg","coloradosprings","arlington"],"build_id_with_prefix":"{{build_id_with_prefix}}","launcher_version":"{{launcher_version}}","api_uri":"{{api_uri}}","store_uri":"{{store_uri}}","build_id":"{{build_id}}","container":"{{container}}","token":"{{token}}","build_prefix":"{{build_prefix}}","build_timeout":"{{build_timeout}}"}' | nomad run -output - > nomad.yaml.tim )
# 
# I copied the kubernetes executor and modified the template.  Very similar.
#
# Author: Greg Fausak
# Fri May  4 06:59:44 CDT 2018
#
# args:
#   build_id_with_prefix  sr-build-1
#   build_prefix          sr-build
#   build_timeout         90
#   launcher_version      stable,latest
#   api_uri               https://api.com
#   store_uri             https://store.com
#   build_id              1
#   container             private.registry.com:5000/image:latest
#   token                 jwt token for chatting with api/store
# 
# need to add:
#   region: us, europe, world
#   datacenter: [ "dc1", "dc2" ]
#

job "{{build_id_with_prefix}}" {
  region = "us"
  datacenters = {{ dc|to_json }}
  type = "batch"

  group "executor" {
    task "executor" {
      driver = "raw_exec"
      config {
        command = "/bin/bash"
        args = [ "local/bootstrap.sh" ]
      }

      template {
        data = <<EOT
LREGISTRY="dockerhub.vcp.vzwops.com:5000"
echo docker pull $LREGISTRY/launcher:{{launcher_version}}
docker pull $LREGISTRY/launcher:{{launcher_version}}
id=$(docker create $LREGISTRY/launcher:{{launcher_version}})
echo 'pull/create {{container}}, make sure the current one is cached'
docker pull {{container}}
docker run \
  --entrypoint "/opt/sd/launcher_entrypoint.sh" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --volumes-from $id \
  {{container}} \
  /opt/sd/run.sh "{{token}}" "{{api_uri}}" "{{store_uri}}" "{{build_timeout}}" "{{build_id}}"
echo 'remove screwdrivercd launcher that we mounted from'
docker rm $id
          EOT
        destination = "local/bootstrap.sh"
      }

      resources {
        cpu = 2000
        memory = 4096
      }

      service {
        name = "launcher"
        tags = [ "screwdriver", "launcher", "{{build_prefix}}" ]
        check {
          type = "script"
          interval = "10s"
          command = "/usr/bin/echo"
          args = [ "okeydokee" ]
          timeout = "2s"
        }
      }
    }
  }
}
