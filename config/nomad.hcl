# vim: tabstop=8 expandtab shiftwidth=2 softtabstop=2
#
# launch the screwdriver executor mounting volumes from screwdrivercd/launcher
#
# this file is used to create the wireline api call for nomad
# there is an issue with the datacenters, need to get that and the regions
# from outside somewhere.  for now, hard coded.
#
# jt nomad.hcl '{"dc":["southlake","arlington"],"build_id_with_prefix":"{{build_id_with_prefix}}","launcher_version":"{{launcher_version}}","api_uri":"{{api_uri}}","store_uri":"{{store_uri}}","build_id":"{{build_id}}","container":"{{container}}","token":"{{token}}"}' | nomad run -output - > nomad.yaml.tim
# 
#
# I basically copied the kubernetes executor and modified the template.
#
# Author: Greg Fausak
# Sun Mar 18 08:31:44 CDT 2018
#
# args:
#   build_id_with_prefix  build-1??
#   launcher_version      stable,latest
#   api_uri               https://api.com
#   store_uri             https://store.com
#   build_id              1
#   container             private.registry.com:5000/image:latest
#   token                 jwt token for chatting with api/store
# 
# jt config/pod.yaml.tim '{"dc":["southlake","arlington"],"build_id_with_prefix":"{{build_id_with_prefix}}","launcher_version":"{{launcher_version}}","api_uri":"{{api_uri}}","store_uri":"{{store_uri}}","build_id":"{{build_id}}","container":"{{container}}","token":"{{token}}"}'
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
docker run \
  --entrypoint /opt/sd/tini \
  --volumes-from $id \
  {{container}} \
  "--" \
  "/bin/sh" \
  "-c" \
  "$LAUNCHER & $LOGGER & \$(wait jobs -p)"
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
        tags = [ "launcher" ]
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
