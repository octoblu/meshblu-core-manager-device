mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'Find Device', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs 'device-manager-test'
      collection: 'devices-test'

    @datastore.remove done

    @cache = new Cache client: redis.createClient uuid.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @cache, @uuidAliasResolver}

  describe 'when called with a subscriberUuid and has devices-test', ->
    beforeEach (done) ->
      record =
        uuid: 'pet-rock'

      @datastore.insert record, done

    beforeEach (done) ->
      @sut.findOne {uuid:'pet-rock'}, (error, @device) => done error

    it 'should have a device', ->
      expect(@device).to.deep.equal uuid: 'pet-rock'
