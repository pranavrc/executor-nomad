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

## Executor


