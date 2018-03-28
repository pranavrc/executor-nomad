# vim: tabstop=8 expandtab shiftwidth=2 softtabstop=2
# Variables:
# id = name of instance (e.g. sd)
# version = (stable,latest,etc)
# registry = (screwdrivercd)
# image = (postgresql)
# dc = datacenters to run in. this is resolved compile time, not run time.
# dbname = (screwdriver, create a database called screwdriver)
# dbuser = (sduser)
# dbpass = (sdpass)
# jt rebootdb.nomad '{"dc":["southlake","arlington"],"id":"{{id}}","version":"{{version}}","registry":"{{registry}}","dbname":"{{dbname}}","dbuser":"{{dbuser}}","dbpass":"{{dbpass}}","image":"{{image}}"}'
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
    ephemeral_disk {
      size = 300
      migrate = true
      sticky = true
    }
    task "{{id}}-box" {
      driver = "docker"
      config {
        image = "{{registry}}/{{image}}:{{version}}"
        port_map = {
          pgport = 5432
        }
      }
      template {
        data = <<ENV
create database "{{dbname}}";
create role "{{dbuser}}" with superuser login password '{{dbpass}}';
ENV
        destination = "local/db.sql"
}

      resources {
        cpu    = 1000 # 500 MHz
        memory = 2048 # 256MB
        network {
          mbits = 10
          port "pgport" { static = 5432 }
        }
      }
      service {
        name = "{{id}}"
        tags = ["postgres" ]
        port = "pgport"
        check {
          name     = "alive"
          type     = "tcp"
          port     = "pgport"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
