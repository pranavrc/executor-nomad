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
# jt nomad.hcl '{"dc":["southlake","branchburg","coloradosprings","arlington"],"build_id_with_prefix":"{{build_id_with_prefix}}","launcher_version":"{{launcher_version}}","api_uri":"{{api_uri}}","store_uri":"{{store_uri}}","build_id":"{{build_id}}","container":"{{container}}","token":"{{token}}","build_prefix":"{{build_prefix}}"}' | nomad run -output - > nomad.yaml.tim
# 
# I copied the kubernetes executor and modified the template.  Very similar.
#
# Author: Greg Fausak
# Sun Mar 18 08:31:44 CDT 2018
#
# args:
#   build_id_with_prefix  sr-build-1
#   build_prefix          sr-build
#   launcher_version      stable,latest
#   api_uri               https://api.com
#   store_uri             https://store.com
#   build_id              1
#   container             private.registry.com:5000/image:latest
#   token                 jwt token for chatting with api/store
# 
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
      env {
        SD_TOKEN = "{{token}}"
      }

      template {
        data = <<EOT
echo 'pull/create screwdrivercd launcher'
docker pull screwdrivercd/launcher:{{launcher_version}}
id=$(docker create screwdrivercd/launcher:{{launcher_version}})
LAUNCHER="/opt/sd/launch --api-uri {{api_uri}} --store-uri {{store_uri}} --emitter /opt/sd/emitter {{build_id}}"
LOGGER="/opt/sd/logservice --emitter /opt/sd/emitter --api-uri {{store_uri}} --build {{build_id}}"
echo 'pull/create {{container}}, make sure the current one is cached'
docker pull {{container}}
docker run \
  --entrypoint /opt/sd/tini \
  -e SD_TOKEN="$SD_TOKEN" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --volumes-from $id \
  {{container}} \
  "--" \
  "/bin/sh" \
  "-c" \
  "$LAUNCHER & $LOGGER & wait \$(jobs -p)"
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
        tags = [ "launcher", "{{build_prefix}}" ]
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
