mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
DeviceManager = require '..'

describe 'Update Device', ->
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
        hungry: 'hippo'
        meshblu:
          updatedAt: '1955-10-26T17:38:14Z'
          updatedBy: '5'

      @datastore.insert record, done

    describe 'when the device is updated', ->
      beforeEach (done) ->
        update =
          $set:
            foo: 'bar'
        @sut.update {uuid:'wet-sock',updatedBy:'foo',data:update}, (error, @result) => done error

      it 'should have a device', (done) ->
        @sut.findOne {uuid: 'wet-sock'}, (error, device) =>
          return done error if error?
          expect(device).to.deep.contain uuid: 'wet-sock', foo: 'bar'
          expect(device.meshblu.updatedAt).not.to.equal '1955-10-26T17:38:14Z'
          expect(device.meshblu.updatedBy).not.to.equal '5'
          expect(device.meshblu.hash).to.exist
          done()

      it 'should yield updated: true', ->
        expect(@result.updated).to.be.true

    describe 'when the device is updated with the same property (so no change)', ->
      beforeEach (done) ->
        update =
          $set:
            hungry: 'hippo'
        @sut.update {uuid:'wet-sock',updatedBy:'foo',data:update}, (error, @result) => done error

      it 'should have a device, but leave updatedBy and updatedAt alone', (done) ->
        @sut.findOne {uuid: 'wet-sock'}, (error, device) =>
          return done error if error?
          expect(device.meshblu.updatedAt).to.equal '1955-10-26T17:38:14Z'
          expect(device.meshblu.updatedBy).to.equal '5'
          done()

      it 'should yield updated: false', ->
        expect(@result.updated).to.be.false

    describe 'when the device is updated with a $ key at the top', ->
      beforeEach (done) ->
        update =
          $set:
            $ref: 'bar'
        @sut.update {uuid:'wet-sock',data:update}, (error) => done error

      it 'should have a device', (done) ->
        @sut.findOne {uuid: 'wet-sock'}, (error, device) =>
          return done error if error?
          expect(device.uuid).to.equal 'wet-sock'
          expect(device.$ref).to.equal 'bar'
          expect(device.meshblu.updatedAt).not.to.equal '1955-10-26T17:38:14Z'
          expect(device.meshblu.hash).to.exist
          done()

    describe 'when the device is updated with a $foo:true at the top', ->
      beforeEach (done) ->
        update = { '$set': { $foo: true } }
        @sut.update {uuid:'wet-sock',data: update}, (error) => done error

      it 'should have a device', (done) ->
        @sut.findOne {uuid: 'wet-sock'}, (error, device) =>
          return done error if error?
          expect(device.uuid).to.equal 'wet-sock'
          expect(device.$foo).to.be.true
          expect(device.meshblu.updatedAt).not.to.equal '1955-10-26T17:38:14Z'
          expect(device.meshblu.hash).to.exist
          done()

    describe 'when the device is updated with a $ key deep', ->
      beforeEach (done) ->
        update =
          $set:
            hello:
              hello:
                $ref: 'bar'
        @sut.update {uuid:'wet-sock',data:update}, (error) => done error

      it 'should have a device', (done) ->
        @sut.findOne {uuid: 'wet-sock'}, (error, device) =>
          return done error if error?
          expect(device.uuid).to.equal 'wet-sock'
          expect(device.hello).to.deep.equal { hello: { $ref: 'bar' } }
          expect(device.meshblu.updatedAt).not.to.equal '1955-10-26T17:38:14Z'
          expect(device.meshblu.hash).to.exist
          done()

    describe 'when the device is updated with a . key', ->
      beforeEach (done) ->
        update =
          $set:
            'hello.hello': 'hi'
        @sut.update {uuid:'wet-sock',data:update}, (error) => done error

      it 'should have a device', (done) ->
        @sut.findOne {uuid: 'wet-sock'}, (error, device) =>
          return done error if error?
          expect(device.uuid).to.equal 'wet-sock'
          expect(device.hello).to.deep.equal { hello: 'hi' }
          expect(device.meshblu.updatedAt).not.to.equal '1955-10-26T17:38:14Z'
          expect(device.meshblu.hash).to.exist
          done()

    describe 'when the device is updated with a $each key', ->
      beforeEach (done) ->
        update =
          $addToSet:
            bananaShapedRocks: $each: ['mummy', 'spoon', 'raisin']

        @sut.update {uuid:'wet-sock',data:update}, (error) => done error

      it 'should have a device', (done) ->
        @sut.findOne {uuid: 'wet-sock'}, (error, device) =>
          expect(device.bananaShapedRocks).to.deep.equal ['mummy', 'spoon', 'raisin']
          done error
