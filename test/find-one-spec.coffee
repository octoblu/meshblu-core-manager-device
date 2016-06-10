mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
MongoKey      = require '../src/mongo-key'
UUID          = require 'uuid'
DeviceManager = require '..'

describe 'Find Device', ->
  beforeEach (done) ->
    database = mongojs 'device-manager-test', ['devices']
    @datastore = new Datastore
      database: database
      collection: 'devices'

    database.devices.remove done

    @cache = new Cache client: redis.createClient UUID.v1()

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

  describe 'with a device with the first value being falsy', ->
    beforeEach (done) ->
      record =
        online: false
        uuid: 'pet-rocky'
        blah: 'blargh'
        hi: 'low'
        super: 'duper'

      @datastore.insert record, done

    beforeEach (done) ->
      @sut.findOne {uuid: 'pet-rocky'}, (error, @device) => done error

    it 'should have a device', ->
      expect(@device).to.deep.equal {
        online: false
        uuid: 'pet-rocky'
        blah: 'blargh'
        hi: 'low'
        super: 'duper'
      }

  describe 'with a device with a collection', ->
    beforeEach (done) ->
      collectionItem = {}
      collectionItem[MongoKey.escape('$foo')] = 'bar'
      record =
        online: false
        uuid: 'pet-rocky'
        blah: 'blargh'
        hi: 'low'
        super: 'duper'
        collection: [
          collectionItem
        ]

      @datastore.insert record, done

    beforeEach (done) ->
      @sut.findOne {uuid: 'pet-rocky'}, (error, @device) => done error

    it 'should have the full device', ->
      expect(@device).to.deep.equal {
        online: false
        uuid: 'pet-rocky'
        blah: 'blargh'
        hi: 'low'
        super: 'duper'
        collection: [
          { $foo: 'bar' }
        ]
      }

  describe 'with a device with a none string collection', ->
    beforeEach (done) ->
      collectionItem = {}
      collectionItem[MongoKey.escape('$foo')] = 'bar'
      record =
        online: false
        uuid: 'pet-rocky'
        blah: 'blargh'
        hi: 'low'
        super: 'duper'
        collection: [
          collectionItem
        ]

      @datastore.insert record, done

    beforeEach (done) ->
      @sut.findOne {uuid: 'pet-rocky'}, (error, @device) => done error

    it 'should have the full device', ->
      expect(@device).to.deep.equal {
        online: false
        uuid: 'pet-rocky'
        blah: 'blargh'
        hi: 'low'
        super: 'duper'
        collection: [
          { $foo: 'bar' }
        ]
      }

  describe 'with a device with a nested object', ->
    beforeEach (done) ->
      item = {}
      item[MongoKey.escape('$foo')] = 'bar'
      record =
        online: false
        uuid: 'pet-rocky'
        blah: 'blargh'
        hi: 'low'
        super: 'duper'
        nested: { item }

      @datastore.insert record, done

    beforeEach (done) ->
      @sut.findOne {uuid: 'pet-rocky'}, (error, @device) => done error

    it 'should have the full device', ->
      expect(@device).to.deep.equal {
        online: false
        uuid: 'pet-rocky'
        blah: 'blargh'
        hi: 'low'
        super: 'duper'
        nested:
          item: { $foo: 'bar' }
      }
