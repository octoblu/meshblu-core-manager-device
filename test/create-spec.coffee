{beforeEach, describe, it} = global
{expect} = require 'chai'

mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
DeviceManager = require '..'

describe 'Create Device', ->
  beforeEach (done) ->
    database = mongojs 'device-manager-test', ['devices']
    @datastore = new Datastore
      database: database
      collection: 'devices'

    database.devices.remove done

  beforeEach ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new DeviceManager {@datastore, @uuidAliasResolver}

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

  describe 'when called with a meshblu key', ->
    beforeEach (done) ->
      @sut.create {type:'not-wet', meshblu: {something: true}}, (error, @device) => done error

    it 'should return you a device with the uuid and token', ->
      expect(@device.uuid).to.exist
      expect(@device.token).to.exist

    it 'should have a device and all of the base properties', (done) ->
      @datastore.findOne { uuid: @device.uuid }, (error, device) =>
        return done error if error?
        expect(device.type).to.equal 'not-wet'
        expect(device.online).to.be.false
        expect(device.uuid).to.exist
        expect(device.token).to.exist
        expect(device.meshblu.something).to.be.true
        expect(device.meshblu.createdAt).to.exist
        expect(device.meshblu.hash).to.exist
        done()

  describe 'when called with online true', ->
    beforeEach (done) ->
      @sut.create { online: true }, (error, @device) => done error

    it 'should return you a device with the uuid and token', ->
      expect(@device.uuid).to.exist
      expect(@device.token).to.exist

    it 'should have a device with online true', (done) ->
      @datastore.findOne {uuid: @device.uuid}, (error, device) =>
        return done error if error?
        expect(device.online).to.be.true
        done()
