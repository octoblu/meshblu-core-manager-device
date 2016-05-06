_                = require 'lodash'
async            = require 'async'
crypto           = require 'crypto'
moment           = require 'moment'
uuid             = require 'uuid'
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
        @datastore.findOne {uuid:newDevice.uuid}, (error, device) =>
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
        async.apply @_updateHash, query
      ], callback

  search: ({uuid, query}, callback) =>
    return callback new Error 'Missing uuid' unless uuid?
    query ?= {}
    secureQuery = @_getSearchWhitelistQuery {uuid, query}
    options =
      limit:     1000
      maxTimeMS: 2000
      sort:      {_id: -1}

    @datastore.find secureQuery, null, options, callback

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
      @datastore.findOne {uuid}, (error, device) =>
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
      requiredProperties =
        uuid: uuid.v4()
        online: false
        token: hashedToken

      newDevice = _.extend {}, properties, requiredProperties
      newDevice.meshblu ?= {}
      newDevice.meshblu.createdAt = moment().format()
      newDevice.meshblu.hash = @_hashObject newDevice
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

  _hashObject: (object) =>
    hasher = crypto.createHash 'sha256'
    hasher.update JSON.stringify object
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

  _updateHash: (query, callback) =>
    @datastore.findOne query, (error, record) =>
      return callback error if error?
      return callback null, null unless record?

      delete record.meshblu?.hash
      hashedDevice = @_hashObject record
      @datastore.update query, $set: {'meshblu.hash': hashedDevice}, callback

  _removeRootTokenInCache: ({token, uuid}, callback) =>
    @cache.del "#{uuid}:#{token}", callback

  _storeRootTokenInCache: ({token, uuid}, callback) =>
    @cache.set "#{uuid}:#{token}", '', callback

module.exports = DeviceManager
