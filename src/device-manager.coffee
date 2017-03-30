_                = require 'lodash'
async            = require 'async'
crypto           = require 'crypto'
UUID             = require 'uuid'
MongoKey         = require './mongo-key'
RootTokenManager = require 'meshblu-core-manager-root-token'

class DeviceManager
  constructor: ({ @datastore,@uuidAliasResolver }) ->
    @rootTokenManager = new RootTokenManager { @datastore, @uuidAliasResolver }
    @keysWeActuallyWant = [
      '$each'
      '$eq'
      '$gt'
      '$gte'
      '$lt'
      '$lte'
      '$ne'
      '$in'
      '$nin'
      '$exists'
      '$all'
      '$elemMatch'
      '$or'
      '$and'
      '$not'
      '$nor'
      '$slice'
    ]

  create: (properties={}, callback) =>
    @_getNewDevice properties, (error, device) =>
      return callback error if error?
      @datastore.insert device, (error) =>
        return callback error if error?
        { uuid } = device
        @rootTokenManager.generateAndStoreToken { uuid }, (error, token) =>
          device.token = token
          callback null, device

  findAndUpdate: ({uuid, projection, data, updatedBy}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      { query, data } = @_extractQuery { uuid, data }
      async.series [
        async.apply @_findAndUpdateDatastore, { query, data, projection }
        async.apply @_updateMetadata, { uuid, updatedBy }
      ], (error, results) =>
        return callback error if error?
        return callback null, results[0]

  findOne: ({uuid, projection}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @_findOne {uuid}, projection, callback

  update: ({uuid, data, updatedBy}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      { query, data } = @_extractQuery { uuid, data }
      @_updateDatastore query, data, (error, response) =>
        return callback error if error?
        return callback() unless response.updated
        @_updateMetadata { uuid, updatedBy}, (error) =>
          return callback error if error?
          return callback null, {updated: response.updated}

  _extractQuery: ({ uuid, data }) =>
    query = data['$query'] ? {}
    data = _.omit data, '$query'
    query.uuid = uuid
    return { query, data }

  search: ({uuid, query, projection}, callback) =>
    return callback new Error 'Missing uuid' unless uuid?
    query ?= {}
    secureQuery = @_getSearchWhitelistQuery {uuid, query}
    options =
      limit:     1000
      maxTimeMS: 2000
      sort:      {_id: -1}

    @datastore.find secureQuery, @_escapeProjection(projection), options, (error, devices) =>
      delete error.code if error?
      return callback error if error?
      callback null, _.map devices, MongoKey.unescapeObj

  recycle: ({uuid}, callback) =>
    return callback new Error('Missing uuid') unless uuid?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @datastore.recycle {uuid}, callback

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
    createdAt = new Date()
    newDevice.meshblu.createdAt = createdAt
    newDevice.meshblu.hash = @_createHash { uuid, createdAt }
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
      'meshblu.version': { $in: [null,'1.0.0'] }

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
      $or: [
        {uuid: uuid}
        {"meshblu.whitelists.discover.view.uuid": $in: ['*', uuid]}
      ]

    return $and: [ versionCheck, whitelistCheck ]

  _escapeProjection: (projection) =>
    return MongoKey.escapeObj projection

  _createHash: ({ uuid, updatedAt, createdAt }) =>
    date = updatedAt.toString() if updatedAt?
    date = createdAt.toString() if createdAt?
    hasher = crypto.createHash 'sha256'
    hasher.update uuid
    hasher.update date
    hasher.digest 'base64'

  _mergeQueryWithWhitelistQuery: (query, whitelistQuery) =>
    whitelistQuery = $and : [whitelistQuery]
    whitelistQuery.$and.push $or: query.$or if query.$or?
    whitelistQuery.$and.push $and: query.$and if query.$and?

    saferQuery = _.omit query, '$or'

    _.extend saferQuery, whitelistQuery

  _findAndUpdateDatastore: ({ query, data, projection }, callback) =>
    _.each data, (datum) =>
      _.each datum, (_, key) =>
        @keysWeActuallyWant.push key if /\.\$\./.test key

    update = _.mapValues data, (datum) => MongoKey.escapeObj datum, @keysWeActuallyWant
    @datastore.findAndUpdate { query, update, projection }, callback

  _updateDatastore: (query, data, callback) =>
    _.each data, (datum) =>
      _.each datum, (_, key) =>
        @keysWeActuallyWant.push key if /\.\$\./.test key

    updateObj = _.mapValues data, (datum) => MongoKey.escapeObj datum, @keysWeActuallyWant
    @datastore.update query, updateObj, callback

  _updateMetadata: ({uuid, updatedBy}, callback) =>
    updatedAt = new Date()
    hash = @_createHash { uuid, updatedAt }
    updateObj = {
      $set: {
        'meshblu.hash': hash
        'meshblu.updatedAt': updatedAt
        'meshblu.updatedBy': updatedBy
      }
    }
    @datastore.update {uuid}, updateObj, callback

module.exports = DeviceManager
