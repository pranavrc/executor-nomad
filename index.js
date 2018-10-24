'use strict';

const Executor = require('screwdriver-executor-base');
const path = require('path');
const Fusebox = require('circuit-fuses');
const request = require('request');
const tinytim = require('tinytim');
const yaml = require('js-yaml');
const fs = require('fs');
const hoek = require('hoek');

class NomadExecutor extends Executor {
    /**
     * Constructor
     * @method constructor
     * @param  {Object} options                                       Configuration options
     * @param  {Object} options.ecosystem                             Screwdriver Ecosystem
     * @param  {Object} options.ecosystem.api                         Routable URI to Screwdriver API
     * @param  {Object} options.ecosystem.store                       Routable URI to Screwdriver Store
     * @param  {Object} options.nomad                                 Nomad configuration
     * @param  {String} [options.nomad.token]                         API Token (loaded from /var/run/secrets/nomad.io/serviceaccount/token if not provided)
     * @param  {String} [options.nomad.host=nomad.default]            Nomad hostname (https://host.com:4646)
     * @param  {String} [options.nomad.resources.cpu.high=600]        Value for HIGH CPU (in Mhz)
     * @param  {Number} [options.nomad.resources.memory.high=4096]    Value for HIGH memory (in MB)
     * @param  {String} [options.launchVersion=stable]                Launcher container version to use
     * @param  {String} [options.buildTimeout=90]                     Build timeout
     * @param  {String} [options.prefix='']                           Prefix for job name
     * @param  {String} [options.fusebox]                             Options for the circuit breaker (https://github.com/screwdriver-cd/circuit-fuses)
     */
    constructor(options = {}) {
        super();

        this.nomad = options.nomad || {};
        this.ecosystem = options.ecosystem;
        if (this.nomad.token) {
            this.token = this.nomad.token;
        } else {
            const tokenPath = '/var/run/secrets/nomad.io/serviceaccount/token';

            this.token = fs.existsSync(tokenPath) ? fs.readFileSync(tokenPath).toString() : '';
        }
        this.host = this.nomad.host || 'nomad.default';
        this.launchVersion = options.launchVersion || 'stable';
        this.buildTimeout = options.buildTimeout || '90';
        this.prefix = options.prefix || '';
        this.breaker = new Fusebox(request, options.fusebox);
        this.highCpu = hoek.reach(options, 'nomad.resources.cpu.high', { default: 600 });
        this.highMemory = hoek.reach(options, 'nomad.resources.memory.high', { default: 1024 });
    }

    /**
     * Starts a nomad build
     * @method start
     * @param  {Object}   config            A configuration object
     * @param  {Integer}  config.buildId    ID for the build
     * @param  {String}   config.container  Container for the build to run in
     * @param  {String}   config.token      JWT for the Build
     * @return {Promise}
     */
    _start(config) {
        const CPU = this.highCpu;
        const MEMORY = this.highMemory;
        const configPath = path.resolve(__dirname, './config/nomad.yaml.tim');
        const nomadTemplate = tinytim.renderFile(configPath, {
            build_id_with_prefix: `${this.prefix}${config.buildId}`,
            build_id: config.buildId,
            build_prefix: this.prefix,
            container: config.container,
            api_uri: this.ecosystem.api,
            store_uri: this.ecosystem.store,
            build_timeout: this.buildTimeout,
            token: config.token,
            launcher_version: this.launchVersion,
            cpu: CPU,
            memory: MEMORY
        });

        const options = {
            uri: `${this.host}/v1/jobs`,
            method: 'POST',
            json: yaml.safeLoad(nomadTemplate),
            strictSSL: false
        };

        return this.breaker.runCommand(options)
            .then((resp) => {
                if (resp.statusCode !== 200) {
                    throw new Error(`Failed to create nomad: ${JSON.stringify(resp.body)}`);
                }

                return null;
            });
    }

    /**
     * Stop a nomad build
     * @method stop
     * @param  {Object}   config            A configuration object
     * @param  {Integer}  config.buildId    ID for the build
     * @return {Promise}
     */
    _stop(config) {
        const options = {
            uri: `${this.host}/v1/job/${this.prefix + config.buildId}`,
            method: 'DELETE',
            strictSSL: false
        };

        return this.breaker.runCommand(options)
            .then((resp) => {
                if (resp.statusCode !== 200) {
                    throw new Error(`Failed to delete nomad: ${JSON.stringify(resp.body)}`);
                }

                return null;
            });
    }

    /**
     * Starts a new periodic build in an executor
     * @method _startPeriodic
     * @return {Promise}  Resolves to null since it's not supported
     */
    _startPeriodic() {
        return Promise.resolve(null);
    }

    /**
     * Stops a new periodic build in an executor
     * @method _stopPeriodic
     * @return {Promise}  Resolves to null since it's not supported
     */
    _stopPeriodic() {
        return Promise.resolve(null);
    }

    /**
    * Retreive stats for the executor
    * @method stats
    * @param  {Response} Object          Object containing stats for the executor
    */
    stats() {
        return this.breaker.stats();
    }
}

module.exports = NomadExecutor;
