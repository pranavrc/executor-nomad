# Nomad with Screwdriver Details

Overview of using Nomad with Screwdriver

## Launch

[Screwdriver](http://github.com/screwdriver-cd) is an implementation
of ci/cd.  It can receive webhooks from an scm (e.g. github) and cause
execution of a screwdriver.yaml build declaration in that repo's home
directory.

[Nomad](https://www.hashicorp.com/) can be used to launch
such a service. Consider an example nomad [job declaration](sd.nomad)
which launches the 3 components of Screwdriver:

* api - Main API
* ui - User interfaces
* store - Object data store

And this [job declaration](psql.nomad) for the relational storage: 

* sql - Relational data store

This example does not take in to account details like
backing up and persisting the sql or object stores. Nor does
it get in to reverse proxy configuration, https support and certificate
management, scm integration, or dns.  What we end up with is
two components of the Screwdriver service.  The first component can
be restarted while the second gives us persistence (except for job output).
The first component has 3 eternally reachable endpoints:

* https://sd-api.DOMAIN.com - The API
* https://sd.DOMAIN.com - The UI
* https://sd-store.DOMAIN.com - Object Storage

The second component creates a single Postgres endpoint:

* sd-psql.DOMAIN.com:5432

Which is used by the api to store all relational information.  This gives
us persistence of Workflows between restarts of the first component.

These two nomad declarations are just examples.  I did take them from an operating
installation.  The thing that you won't see in them is how you get ip addresses assigned
and reverse proxies configured.  If you are running Nomad you probably have
Consul up, and you can drive dns / reverse proxy configuration from consul_template.

## Executor

The more interesting use with Nomad is what Screwdriver calls an executor. Several
are supported including Docker and Kubernetes.  Using the Kubernetes work, I saw an
easy way to create a Nomad driver.  These assumptions are made:

* Nomad is up and running.
* You have the raw_exec enabled on all Nomad clients
* You have docker enabled on all Nomad clients

Given those prerequisites we can use Nomad as the engine for Screwdriver.

A screwdriver.yaml file is what defines the docker instance
you want to use to run a build. For example, I may have a declaration:

```
jobs:
  main:
    image: python:2.7
    requires: [~pr, ~commit]
    steps:
      - first: echo 'hello'
      - setanenv: export OPERATION=install
      - makeproduct: python setup.py $OPERATION
```

This contrived example declares that we will use the docker python:2.7 image to
run our installation steps. What actually occurs is:

* screwdrivercd/launcher docker instance is pulled and created.
* python:2.7 is pulled and started with volumes from launcher. The entrypoint is
  intercepted to run the job and run logging.

The technique used for doing this in Nomad was to use the raw_exec module
to run a script that is created by the [nomad.hcl](../config/nomad.hcl) file.
This is run to accomplish the docker run with volumes from (until it
is supported in Nomad's own docker driver).

