'use strict';

const assert = require('chai').assert;
const sinon = require('sinon');
const mockery = require('mockery');

sinon.assert.expose(assert, { prefix: '' });

const TEST_TIM_YAML = `
metadata:
  name: {{build_id_with_prefix}}
  container: {{container}}
  launchVersion: {{launcher_version}}
  cpu: {{cpu}}
  memory: {{memory}}
command:
- "/opt/sd/launch {{api_uri}} {{store_uri}} {{token}} {{build_id}}"
`;

describe('index', function () {
    // Time not important. Only life important.
    this.timeout(5000);

    let Executor;
    let requestMock;
    let fsMock;
    let executor;
    const testBuildId = 15;
    const testToken = 'abcdefg';
    const testApiUri = 'http://api:8080';
    const testStoreUri = 'http://store:8080';
    const testContainer = 'node:4';
    const testServiceAccount = 'foobar';
    const testLaunchVersion = 'stable';
    const nomadUrl = 'https://nomad.default/v1/jobs';

    before(() => {
        mockery.enable({
            useCleanCache: true,
            warnOnUnregistered: false
        });
    });

    beforeEach(() => {
        requestMock = sinon.stub();

        fsMock = {
            existsSync: sinon.stub(),
            readFileSync: sinon.stub()
        };

        fsMock.existsSync.returns(true);

        fsMock.readFileSync.withArgs('/var/run/secrets/nomad.io/serviceaccount/token')
            .returns('api_key');
        fsMock.readFileSync.withArgs(sinon.match(/config\/nomad.yaml.tim/))
            .returns(TEST_TIM_YAML);

        mockery.registerMock('fs', fsMock);
        mockery.registerMock('request', requestMock);

        /* eslint-disable global-require */
        Executor = require('../index');
        /* eslint-enable global-require */

        executor = new Executor({
            ecosystem: {
                api: testApiUri,
                store: testStoreUri
            },
            fusebox: { retry: { minTimeout: 1 } },
            prefix: 'beta_'
        });
    });

    afterEach(() => {
        mockery.deregisterAll();
        mockery.resetCache();
    });

    after(() => {
        mockery.disable();
    });

    it('supports specifying a specific version', () => {
        assert.equal(executor.launchVersion, 'stable');
        assert.equal(executor.token, 'api_key');
        assert.equal(executor.host, 'nomad.default');
        executor = new Executor({
            nomad: {
                token: 'api_key2',
                host: 'nomad2',
                serviceAccount: 'foobar',
                jobsNamespace: 'baz',
                resources: {
                    cpu: {
                        high: 600
                    },
                    memory: {
                        high: 4000
                    }
                }
            },
            prefix: 'beta_',
            launchVersion: 'v1.2.3'
        });

        assert.equal(executor.prefix, 'beta_');
        assert.equal(executor.token, 'api_key2');
        assert.equal(executor.host, 'nomad2');
        assert.equal(executor.launchVersion, 'v1.2.3');
        assert.equal(executor.nomad.jobsNamespace, 'baz');
        assert.equal(executor.highCpu, 600);
        assert.equal(executor.highMemory, 4000);
    });

    it('allow empty options', () => {
        fsMock.existsSync.returns(false);
        executor = new Executor();
        assert.equal(executor.launchVersion, 'stable');
        assert.equal(executor.token, '');
        assert.equal(executor.host, 'nomad.default');
        assert.equal(executor.launchVersion, 'stable');
        assert.equal(executor.prefix, '');
        assert.equal(executor.highCpu, 600);
        assert.equal(executor.highMemory, 1024); // { default: 1024 }
    });

    it('extends base class', () => {
        assert.isFunction(executor.stop);
        assert.isFunction(executor.start);
    });

    describe('stats', () => {
        it('returns the correct stats', () => {
            assert.deepEqual(executor.stats(), {
                requests: {
                    total: 0,
                    timeouts: 0,
                    success: 0,
                    failure: 0,
                    concurrent: 0,
                    averageTime: 0
                },
                breaker: {
                    isClosed: true
                }
            });
        });
    });

    describe('stop', () => {
        const fakeStopResponse = {
            statusCode: 200,
            body: {
                success: 'true'
            }
        };
        const deleteConfig = {
            uri: 'nomad.default/v1/job/beta_15',
            method: 'DELETE',
            strictSSL: false
        };

        beforeEach(() => {
            requestMock.yieldsAsync(null, fakeStopResponse, fakeStopResponse.body);
        });

        it('calls breaker with correct config', () => (
            executor.stop({
                buildId: testBuildId
            }).then(() => {
                assert.calledWith(requestMock, deleteConfig);
                assert.calledOnce(requestMock);
            })
        ));

        it('returns error when breaker does', () => {
            const error = new Error('error');

            requestMock.yieldsAsync(error);

            return executor.stop({
                buildId: testBuildId
            }).then(() => {
                throw new Error('did not fail');
            }, (err) => {
                assert.deepEqual(err, error);
                assert.equal(requestMock.callCount, 5);
            });
        });

        it('returns error when response is non 200', () => {
            const fakeStopErrorResponse = {
                statusCode: 500,
                body: {
                    error: 'foo'
                }
            };

            const returnMessage = 'Failed to delete nomad: '
                  + `${JSON.stringify(fakeStopErrorResponse.body)}`;

            requestMock.yieldsAsync(null, fakeStopErrorResponse, fakeStopErrorResponse.body);

            return executor.stop({
                buildId: testBuildId
            }).then(() => {
                throw new Error('did not fail');
            }, (err) => {
                assert.equal(err.message, returnMessage);
            });
        });
    });

    describe('start', () => {
        const fakeStartResponse = {
            statusCode: 201,
            body: {
                success: true
            }
        };
        const postConfig = {
            uri: nomadUrl,
            method: 'POST',
            json: {
                metadata: {
                    name: 'beta_15',
                    container: testContainer,
                    launchVersion: testLaunchVersion,
                    serviceAccount: testServiceAccount,
                    cpu: 2000,
                    memory: 2
                },
                command: [
                    '/opt/sd/launch http://api:8080 http://store:8080 abcdefg '
                    + '15'
                ]
            },
            headers: {
                Authorization: 'Bearer api_key'
            },
            strictSSL: false
        };

        beforeEach(() => {
            requestMock.yieldsAsync(null, fakeStartResponse, fakeStartResponse.body);
        });

        it('successfully calls start', () => {
            executor.start({
                buildId: testBuildId,
                container: testContainer,
                token: testToken,
                apiUri: testApiUri
            }).then(() => {
                assert.calledOnce(requestMock);
                assert.calledWith(requestMock, postConfig);
            });
        });

        it('sets the memory appropriately when ram is set to HIGH', () => {
            postConfig.json.metadata.cpu = 2000;
            postConfig.json.metadata.memory = 12;

            executor.start({
                annotations: {
                    'beta.screwdriver.cd/ram': 'HIGH'
                },
                buildId: testBuildId,
                container: testContainer,
                token: testToken,
                apiUri: testApiUri
            }).then(() => {
                assert.calledOnce(requestMock);
                assert.calledWith(requestMock, postConfig);
            });
        });

        it('sets the cpu appropriately when cpu is set to HIGH', () => {
            postConfig.json.metadata.cpu = 6000;
            postConfig.json.metadata.memory = 2;

            executor.start({
                annotations: {
                    'beta.screwdriver.cd/cpu': 'HIGH'
                },
                buildId: testBuildId,
                container: testContainer,
                token: testToken,
                apiUri: testApiUri
            }).then(() => {
                assert.calledOnce(requestMock);
                assert.calledWith(requestMock, postConfig);
            });
        });

        it('returns error when request responds with error', () => {
            const error = new Error('lol');

            requestMock.yieldsAsync(error);

            return executor.start({
                buildId: testBuildId,
                container: testContainer,
                token: testToken,
                apiUri: testApiUri
            }).then(() => {
                throw new Error('did not fail');
            }, (err) => {
                assert.deepEqual(err, error);
            });
        });

        it('returns body when request responds with error in response', () => {
            const returnResponse = {
                statusCode: 500,
                body: {
                    statusCode: 500,
                    message: 'lol'
                }
            };
            const returnMessage = `Failed to create nomad: ${JSON.stringify(returnResponse.body)}`;

            requestMock.yieldsAsync(null, returnResponse, returnResponse.body);

            return executor.start({
                buildId: testBuildId,
                container: testContainer,
                token: testToken,
                apiUri: testApiUri
            }).then(() => {
                throw new Error('did not fail');
            }, (err) => {
                assert.equal(err.message, returnMessage);
            });
        });
    });

    describe('periodic', () => {
        it('resolves to null when calling periodic start',
            () => executor.startPeriodic().then(res => assert.isNull(res)));

        it('resolves to null when calling periodic stop',
            () => executor.stopPeriodic().then(res => assert.isNull(res)));
    });

    describe('frozen', () => {
        it('resolves to null when calling frozen start',
            () => executor.startFrozen().then(res => assert.isNull(res)));

        it('resolves to null when calling frozen stop',
            () => executor.stopFrozen().then(res => assert.isNull(res)));
    });
});
