mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
DeviceManager = require '..'

describe 'Query with $elemMatch', ->
  beforeEach (done) ->
    database = mongojs 'device-manager-test', ['devices']
    @datastore = new Datastore
      database: database
      collection: 'devices'

    database.devices.remove done

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @uuidAliasResolver}

  describe 'when the device exists', ->
    beforeEach (done) ->
      record =
        uuid: 'wet-sock'
        pairings: [
          {
            foot: 'left'
          }
          {
            foot: 'right'
          }
        ]

      @datastore.insert record, done

    describe 'when the device is updated', ->
      beforeEach (done) ->
        update =
          $query:
            pairings:
              $elemMatch:
                foot: 'left'
          $set:
            'pairings.$.condition': 'bad'

        @sut.update {uuid:'wet-sock',data:update}, (error) => done error

      it 'should update the left sock', (done) ->
        @sut.findOne {uuid: 'wet-sock'}, (error, device) =>
          return done error if error?
          expect(device).to.deep.contain uuid: 'wet-sock'
          expect(device.pairings[0]).to.deep.contain foot: 'left', condition: 'bad'
          expect(device.pairings[1]).to.deep.equal foot: 'right'
          done()
