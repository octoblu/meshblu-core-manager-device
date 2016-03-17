mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'Create Device', ->
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
      @sut.create {type:'not-wet'}, (error, @device) => done error

    it 'should return you a device with the uuid and token', ->
      expect(@device.uuid).to.exist
      expect(@device.token).to.exist

    it 'should have a device and all of the base properties', (done) ->
      @datastore.findOne {uuid: @device.uuid}, (error, device) =>
        return done error if error?
        expect(device.type).to.equal 'not-wet'
        expect(device.online).to.be.false
        expect(device.uuid).to.exist
        expect(device.token).to.exist
        expect(device.meshblu.createdAt).to.exist
        expect(device.meshblu.hash).to.exist
        done()

    it 'should create the token in the cache', (done) ->
      @datastore.findOne {uuid: @device.uuid}, (error, device) =>
        return done error if error?
        @cache.exists "meshblu-token-cache:#{device.uuid}:#{device.token}", (error, result) =>
          return done error if error?
          expect(result).to.be.true
          done()

  describe 'when called with a meshblu key', ->
    beforeEach (done) ->
      @sut.create {type:'not-wet', meshblu: {something: true}}, (error, @device) => done error

    it 'should return you a device with the uuid and token', ->
      expect(@device.uuid).to.exist
      expect(@device.token).to.exist

    it 'should have a device and all of the base properties', (done) ->
      @datastore.findOne {uuid: @device.uuid}, (error, device) =>
        return done error if error?
        expect(device.type).to.equal 'not-wet'
        expect(device.online).to.be.false
        expect(device.uuid).to.exist
        expect(device.token).to.exist
        expect(device.meshblu.something).to.be.true
        expect(device.meshblu.createdAt).to.exist
        expect(device.meshblu.hash).to.exist
        done()

    it 'should create the token in the cache', (done) ->
      @datastore.findOne {uuid: @device.uuid}, (error, device) =>
        return done error if error?
        @cache.exists "meshblu-token-cache:#{device.uuid}:#{device.token}", (error, result) =>
          return done error if error?
          expect(result).to.be.true
          done()
