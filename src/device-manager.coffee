_                = require 'lodash'
async            = require 'async'
crypto           = require 'crypto'
moment           = require 'moment'
UUID             = require 'uuid'
MongoKey         = require './mongo-key'
RootTokenManager = require 'meshblu-core-manager-root-token'

class DeviceManager
  constructor: ({ @datastore,@uuidAliasResolver }) ->
    @rootTokenManager = new RootTokenManager { @datastore, @uuidAliasResolver }

  create: (properties={}, callback) =>
    @_getNewDevice properties, (error, device) =>
      return callback error if error?
      @datastore.insert device, (error) =>
        return callback error if error?
        { uuid } = device
        @rootTokenManager.generateAndStoreToken { uuid }, (error, token) =>
          device.token = token
          callback null, device

  findOne: ({uuid, projection}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @_findOne {uuid}, projection, callback

  update: ({uuid, data}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      async.series [
        async.apply @_updateDatastore, {uuid}, data
        async.apply @_updateUpdatedAt, {uuid}
        async.apply @_updateHash, {uuid}, {uuid}
      ], callback

  search: ({uuid, query, projection}, callback) =>
    return callback new Error 'Missing uuid' unless uuid?
    query ?= {}
    secureQuery = @_getSearchWhitelistQuery {uuid, query}
    options =
      limit:     1000
      maxTimeMS: 2000
      sort:      {_id: -1}

    @datastore.find secureQuery, @_escapeProjection(projection), options, (error, devices) =>
      return callback error if error?
      callback null, _.map devices, MongoKey.unescapeObj

  remove: ({uuid}, callback) =>
    return callback new Error('Missing uuid') unless uuid?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @datastore.remove {uuid}, callback

  _findOne: (query, projection, callback) =>
    @datastore.findOne query, @_escapeProjection(projection), (error, device) =>
      return callback error if error?
      callback null, MongoKey.unescapeObj device

  _getNewDevice: (properties={}, callback) =>
    uuid = UUID.v4()
    requiredProperties = { uuid }
    newDevice = _.extend { online: false }, properties, requiredProperties
    newDevice.meshblu ?= {}
    newDevice.meshblu.createdAt = new Date()
    newDevice.meshblu.hash = @_createHash { uuid }
    callback null, newDevice

  _getSearchWhitelistQuery: ({uuid,query}) =>
    whitelistCheck =
      $or: [
        @_getOGWhitelistCheck {uuid}
        @_getV2WhitelistCheck {uuid}
      ]
    @_mergeQueryWithWhitelistQuery query, whitelistCheck

  _getOGWhitelistCheck: ({uuid}) =>
    versionCheck =
      'meshblu.version': { $ne: '2.0.0' }

    whitelistCheck =
      $or: [
        {uuid: uuid}
        {owner: uuid}
        {discoverWhitelist: $in: ['*', uuid]}
      ]

    return $and: [ versionCheck, whitelistCheck ]

  _getV2WhitelistCheck: ({uuid}) =>
    versionCheck =
      'meshblu.version': '2.0.0'

    whitelistCheck =
      {"meshblu.whitelists.discover.view.uuid": $in: ['*', uuid]}

    return $and: [ versionCheck, whitelistCheck ]

  _escapeProjection: (projection) =>
    return MongoKey.escapeObj projection

  _createHash: ({ uuid }) =>
    hasher = crypto.createHash 'sha256'
    hasher.update uuid
    hasher.update moment().format()
    hasher.digest 'base64'

  _mergeQueryWithWhitelistQuery: (query, whitelistQuery) =>
    whitelistQuery = $and : [whitelistQuery]
    whitelistQuery.$and.push $or: query.$or if query.$or?
    whitelistQuery.$and.push $and: query.$and if query.$and?

    saferQuery = _.omit query, '$or'

    _.extend saferQuery, whitelistQuery

  _updateDatastore: (query, data, callback) =>
    keysWeActuallyWant = ['$each']
    updateObj = _.mapValues data, (datum) => MongoKey.escapeObj datum, keysWeActuallyWant
    @datastore.update query, updateObj, callback

  _updateUpdatedAt: (query, callback) =>
    @datastore.update query, $set: {'meshblu.updatedAt': moment().format()}, callback

  _updateHash: (query, {uuid}, callback) =>
    hash = @_createHash {uuid}
    @datastore.update query, $set: {'meshblu.hash': hash}, callback

module.exports = DeviceManager
