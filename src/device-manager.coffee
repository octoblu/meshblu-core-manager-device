_                = require 'lodash'
async            = require 'async'
crypto           = require 'crypto'
moment           = require 'moment'
UUID             = require 'uuid'
RootTokenManager = require './root-token-manager'

class DeviceManager
  constructor: ({@datastore,@uuidAliasResolver,@cache}) ->
    @rootTokenManager = new RootTokenManager

  create: (properties={}, callback) =>
    token = @rootTokenManager.generate()
    @_getNewDevice properties, token, (error, newDevice) =>
      return callback error if error?
      @datastore.insert newDevice, (error) =>
        return callback error if error?
        @datastore.findOne {uuid: newDevice.uuid}, (error, device) =>
          return callback error if error?
          @_storeRootTokenInCache device, (error) =>
            return callback error if error?
            device.token = token
            callback null, device

  findOne: ({uuid, projection}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      query = {uuid}
      @datastore.findOne query, projection, callback

  update: ({uuid, data}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      query = {uuid}

      async.series [
        async.apply @_updateDatastore, query, data
        async.apply @_updateUpdatedAt, query
        async.apply @_updateHash, query, {uuid}
      ], callback

  search: ({uuid, query, projection}, callback) =>
    return callback new Error 'Missing uuid' unless uuid?
    query ?= {}
    secureQuery = @_getSearchWhitelistQuery {uuid, query}
    options =
      limit:     1000
      maxTimeMS: 2000
      sort:      {_id: -1}

    @datastore.find secureQuery, projection, options, callback

  remove: ({uuid}, callback) =>
    return callback new Error('Missing uuid') unless uuid?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @datastore.remove {uuid}, callback

  removeDeviceFromCache: ({uuid}, callback) =>
    @cache.del uuid, callback

  resetRootToken: ({uuid}, callback) =>
    return callback new Error 'Missing uuid' unless uuid?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      projection =
        uuid: true
        token: true
      @datastore.findOne {uuid}, projection, (error, device) =>
        @_removeRootTokenInCache {uuid, token: device.token}, (error) =>
          return callback error if error?
          token = @rootTokenManager.generate()
          @update {uuid, data: {$set: {token}}}, (error) =>
            return callback error if error?
            @_storeRootTokenInCache {uuid, token}, (error) =>
              return callback error if error?
              callback null, {uuid, token}

  _getNewDevice: (properties={}, token, callback) =>
    @rootTokenManager.hash token, (error, hashedToken) =>
      return callback error if error?
      uuid = UUID.v4()
      requiredProperties =
        uuid: uuid
        online: false
        token: hashedToken

      newDevice = _.extend {}, properties, requiredProperties
      newDevice.meshblu ?= {}
      newDevice.meshblu.createdAt = moment().format()
      newDevice.meshblu.hash = @_createHash {uuid}
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

  _createHash: (object) =>
    hasher = crypto.createHash 'sha256'
    hasher.update object.uuid
    hasher.update moment().format()
    hasher.digest 'base64'

  _mergeQueryWithWhitelistQuery: (query, whitelistQuery) =>
    whitelistQuery = $and : [whitelistQuery]
    whitelistQuery.$and.push $or: query.$or if query.$or?
    whitelistQuery.$and.push $and: query.$and if query.$and?

    saferQuery = _.omit query, '$or'

    _.extend saferQuery, whitelistQuery

  _updateDatastore: (query, data, callback) =>
    @datastore.update query, data, callback

  _updateUpdatedAt: (query, callback) =>
    @datastore.update query, $set: {'meshblu.updatedAt': moment().format()}, callback

  _updateHash: (query, {uuid}, callback) =>
    hash = @_createHash {uuid}
    @datastore.update query, $set: {'meshblu.hash': hash}, callback

  _removeRootTokenInCache: ({token, uuid}, callback) =>
    @cache.del "#{uuid}:#{token}", callback

  _storeRootTokenInCache: ({token, uuid}, callback) =>
    @cache.set "#{uuid}:#{token}", '', callback

module.exports = DeviceManager
