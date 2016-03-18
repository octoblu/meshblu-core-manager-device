mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'Reset Token', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs 'device-manager-test'
      collection: 'devices-test'

    @datastore.remove done

    @cache = new Cache client: redis.createClient uuid.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @cache, @uuidAliasResolver}

  describe 'when called', ->
    beforeEach (done) ->
      device =
        uuid: 'some-device'
        token: 'should-change'
        somethingelse: 'this-should-exist'

      @datastore.insert device, done

    beforeEach (done) ->
      @sut.resetRootToken {uuid: 'some-device'}, (error, @response) => done error

    it 'should have a device and all of the base properties', (done) ->
      @datastore.findOne {uuid: 'some-device'}, (error, device) =>
        return done error if error?
        expect(device.token).to.exist
        expect(device.token).to.not.equal 'should-change'
        expect(device.somethingelse).to.equal 'this-should-exist'
        done()

    it 'should respond with the uuid and token', ->
      expect(@response.uuid).to.equal 'some-device'
      expect(@response.token).to.exist

  describe 'when called without a uuid', ->
    beforeEach (done) ->
      @sut.resetRootToken {uuid: null}, (@error) => done()

    it 'should have an error with a code of 422', ->
      expect(@error.message).to.equal 'Missing uuid'
