_             = require 'lodash'
mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
Cache         = require 'meshblu-core-cache'
redis         = require 'fakeredis'
uuid          = require 'uuid'
DeviceManager = require '..'

describe 'Search Devices', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs 'device-manager-test'
      collection: 'devices-test'

    @datastore.remove done

    @cache = new Cache client: redis.createClient uuid.v1()

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @cache, @uuidAliasResolver}

  describe 'when called without a uuid', ->
    beforeEach (done) ->
      @sut.search {uuid: null}, (@error) => done()

    it 'should have an error', ->
      expect(@error.message).to.equal 'Missing uuid'

  describe 'when devices are stored in the database', ->
    beforeEach (done) ->
      sabers = [
        {
          uuid: 'curve-hilted'
          type: 'light-saber'
          color: 'blue'
        }
        {
          uuid: 'underwater-lightsaber'
          owner: 'darth-vader'
          type: 'light-saber'
        }
        {
          uuid: 'great-lightsaber'
          configureWhitelist: ['*']
          type: 'light-saber'
        }
        {
          uuid: 'fire-saber'
          type: 'light-saber'
          discoverWhitelist: ['darth-vader']
        }
        {
          uuid: 'dual-phase-lightsaber'
          type: 'light-saber'
          color: 'red'
          discoverWhitelist: ['*']
        }
        {
          uuid: 'darth-vader'
          type: 'sith-lord'
        }
      ]
      @datastore.insert sabers, done

    describe 'when called and it will find devices', ->
      beforeEach (done) ->
        @sut.search {uuid: 'darth-vader', query: {type:'light-saber'}}, (error, @devices) => done error

      it 'should return 3 devices', ->
        expect(@devices.length).to.equal 3

    describe 'when called with a null query and it will find devices', ->
      beforeEach (done) ->
        @sut.search {uuid: 'darth-vader', query: null}, (error, @devices) => done error

      it 'should return 3 devices', ->
        expect(@devices.length).to.equal 4

    describe 'when called with an empty query and it will find devices', ->
      beforeEach (done) ->
        @sut.search {uuid: 'darth-vader', query: null}, (error, @devices) => done error

      it 'should return 3 devices', ->
        expect(@devices.length).to.equal 4

  describe 'when a 1100 devices are created', ->
    beforeEach (done) ->
      sabers = _.times 1100, =>
        return {
          uuid: 'fire-saber'
          type: 'light-saber'
          discoverWhitelist: ['darth-vader']
        }
      @datastore.insert sabers, done

    describe 'when called and it will find only a 1000 devices', ->
      beforeEach (done) ->
        @sut.search {uuid: 'darth-vader', query: {type:'light-saber'}}, (error, @devices) => done error

      it 'should return 1000 devices', ->
        expect(@devices.length).to.equal 1000
