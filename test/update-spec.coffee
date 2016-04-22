mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'Update Device', ->
  beforeEach (done) ->
    database = mongojs 'device-manager-test', ['devices']
    @datastore = new Datastore
      database: database
      collection: 'devices'

    database.devices.remove done

    @cache = new Cache client: redis.createClient uuid.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @cache, @uuidAliasResolver}

  describe 'when the device exists', ->
    beforeEach (done) ->
      record =
        uuid: 'wet-sock'

      @datastore.insert record, done

    beforeEach (done) ->
      update =
        $set:
          foo: 'bar'
      @sut.update {uuid:'wet-sock',data:update}, (error) => done error

    it 'should have a device', (done) ->
      @datastore.findOne {uuid: 'wet-sock'}, (error, device) =>
        return done error if error?
        expect(device).to.deep.contain uuid: 'wet-sock', foo: 'bar'
        expect(device.meshblu.updatedAt).not.to.be.undefined
        expect(device.meshblu.hash).not.to.be.undefined
        done()
