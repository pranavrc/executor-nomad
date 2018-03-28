# id = name of instance (sd,screwd,etc)
# version = (stable,latest,etc)
# registry = (screwdrivercd,dockerhub.vcp.vzwops.com:5000,etc)
# image = (screwdriver)
# imageui = (ui)
# imagestore = (store)
# dc = datacenters to run in. this is resolved compile time, not run time.
# domain = (my.domain.com)
# psqlid = (sd-psql,etc)
# clientid = oauth client id, create oauth application on github
# clientsecret = oauth client secret.
# nomadurl = http://192.168.30.30:4646
#
# note: the jwt public and private keys could/should be auto generated
# or input from broccoli user.
#
# screwdriver.nomad
#

job "{{id}}" {
  region = "us"
  datacenters = {{dc|to_json}}
  type = "service"
  update {
    stagger = "10s"
    max_parallel = 1
  }
  group "{{id}}-box" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }
    task "{{id}}-api" {
      driver = "docker"
      
      config {
        image = "{{registry}}/{{image}}:{{version}}"
        command  = "/bin/sh"
        args  = [ "/local/bootstrap.sh" ]
        force_pull = true
        port_map = {
          http = 80
        }
      }
      # should bundle these in a tar file
      template {
        data = <<EOT
#!/usr/bin/env sh
#
cp /local/local.yaml /config/.
exec bin/server
EOT
        destination = "local/bootstrap.sh"
      }
      template {
        data = <<EOT
---
auth:
  https: true
  jwtPrivateKey: |
    -----BEGIN RSA PRIVATE KEY-----
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ..........         YOUR PRIVATE JWT KEY            .............
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    ................................................................
    -----END RSA PRIVATE KEY-----
  jwtPublicKey: |
    -----BEGIN PUBLIC KEY-----
    ................................................................
    ................................................................
    ................................................................
    ..........         YOUR  PUBLIC JWT KEY            .............
    ................................................................
    ................................................................
    ................................................................
    -----END PUBLIC KEY-----
  cookiePassword: 0937298572935792375927598237598732598755
  encryptionPassword: 9327927502140101701750702395712057100040

httpd:
  port: 80
  host: 0.0.0.0
  uri: https://{{id}}-api.{{domain}}

ecosystem:
  # Externally routable URL for the User Interface
  ui: https://{{id}}.{{domain}}
  # Externally routable URL for the Artifact Store
  store: https://{{id}}-store.{{domain}}
  # Badge service (needs to add a status and color)
  badges: https://img.shields.io/badge/build--.svg

datastore:
  plugin: sequelize
  sequelize:
    dialect: postgres
    database: screwdriver
    username: sduser
    password: sdpass
    host: {{psqlid}}.{{domain}}
    port: 5432

executor:
  plugin: nomad
  nomad:
    options:
      nomad:
        host: {{nomadurl}}
      resources:
        cpu:
          high: 600
        memory:
          high: 4096
      launchVersion: {{version}}
      prefix: '{{id}}-build-'

#notifications:
#    slack:
#        token: 'xoxb-abbaababaabaababababababababababababb'

# config/local.yaml
scms:
  github.private.com:
    plugin: github
    config:
      oauthClientId: {{ clientid }}
      oauthClientSecret: {{ clientsecret }}
      secret: SUPER-SECRET-SIGNING-THING
      gheHost: github.private.com
      gheProtocol: https
      username: {{id}}-buildbot
      email: anybody@somewhere
EOT
        destination = "local/local.yaml"
      }

      resources {
        cpu    = 6000 # 500 MHz
        memory = 8192 # 256MB
        network {
          mbits = 10
          port "http" { }
        }
      }
      service {
        name = "{{id}}-api"
        tags = ["{{id}}-box" ]
        port = "http"
        check {
          name     = "alive"
          type     = "http"
          path     = "/v4/status"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
    task "{{id}}" {
      driver = "docker"
      config {
        image = "{{registry}}/{{imageui}}:{{version}}"
        force_pull = true
        port_map = {
          http = 80
        }
      }
      env {
        URI = "https://{{id}}.{{domain}}"
        ECOSYSTEM_API = "https://{{id}}-api.{{domain}}"
        ECOSYSTEM_STORE = "https://{{id}}-store.{{domain}}"
        AVATAR_HOSTNAME = "avatars*.githubusercontent.com"
      }

      resources {
        cpu    = 6000 # 500 MHz
        memory = 8192 # 256MB
        network {
          mbits = 10
          port "http" { }
        }
      }
      service {
        name = "{{id}}"
        tags = ["{{id}}-box" ]
        port = "http"
        check {
          name     = "alive"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
    task "{{id}}-store" {
      driver = "docker"
      config {
        image = "{{registry}}/{{imagestore}}:{{version}}"
        force_pull = true
        port_map = {
          http = 80
        }
      }
      env {
        URI = "https://{{id}}-store.{{domain}}"
        ECOSYSTEM_UI = "https://{{id}}.{{domain}}"
        SECRET_JWT_PUBLIC_KEY = "-----BEGIN PUBLIC KEY-----
................................................................
................................................................
................................................................
..........         YOUR  PUBLIC JWT KEY            .............
................................................................
................................................................
................................................................
-----END PUBLIC KEY-----
"
      }

      resources {
        cpu    = 6000 # 500 MHz
        memory = 8192 # 256MB
        network {
          mbits = 10
          port "http" { }
        }
      }
      service {
        name = "{{id}}-store"
        tags = ["{{id}}-box" ]
        port = "http"
        check {
          name     = "alive"
          type     = "http"
          path     = "/v1/status"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
