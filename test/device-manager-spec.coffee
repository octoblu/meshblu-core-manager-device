mongojs = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
DeviceManager = require '..'

describe 'DeviceManager', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs 'subscription-manager-test'
      collection: 'subscriptions'

    @datastore.remove done

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @uuidAliasResolver}

  describe '->findOne', ->
    describe 'when called with a subscriberUuid and has subscriptions', ->
      beforeEach (done) ->
        record =
          uuid: 'pet-rock'

        @datastore.insert record, done

      beforeEach (done) ->
        @sut.findOne {uuid:'pet-rock'}, (error, @device) => done error

      it 'should have a device', ->
        expect(@device).to.deep.equal uuid: 'pet-rock'
