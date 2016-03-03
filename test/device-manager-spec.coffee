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

  describe '->update', ->
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
