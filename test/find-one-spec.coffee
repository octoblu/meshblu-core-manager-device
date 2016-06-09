mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
MongoKey      = require '../src/mongo-key'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'Find Device', ->
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

  describe 'when called with a subscriberUuid and has devices-test', ->
    beforeEach (done) ->
      refKey = MongoKey.escape '$ref'
      record =
        uuid: 'pet-rock'
        something: {}
      record.something[refKey] = 'oh-no'

      @datastore.insert record, done

    beforeEach (done) ->
      @sut.findOne {uuid:'pet-rock'}, (error, @device) => done error

    it 'should have a device', ->
      expect(@device.uuid).to.equal 'pet-rock'
      expect(@device.something['$ref']).to.equal 'oh-no'

  describe 'with a projection', ->
    beforeEach (done) ->
      record =
        uuid: 'pet-rock'
        blah: 'blargh'
        hi: 'low'

      @datastore.insert record, done

    beforeEach (done) ->
      uuid = 'pet-rock'
      projection = hi: false

      @sut.findOne {uuid, projection}, (error, @device) => done error

    it 'should have a device with projection', ->
      expect(@device).to.deep.equal uuid: 'pet-rock', blah: 'blargh'
