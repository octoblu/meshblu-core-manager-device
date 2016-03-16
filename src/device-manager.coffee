_      = require 'lodash'
async  = require 'async'
crypto = require 'crypto'
moment = require 'moment'
uuid   = require 'uuid'
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
        @findOne {uuid:newDevice.uuid}, (error, device) =>
          return callback error if error?
          @_storeRootTokenInCache device, (error) =>
            return callback error if error?
            device.token = token
            callback null, device

  findOne: ({uuid}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      query = {uuid}
      @datastore.findOne query, callback

  update: ({uuid, data}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      query = {uuid}

      async.series [
        async.apply @_updateDatastore, query, data
        async.apply @_updateUpdatedAt, query
        async.apply @_updateHash, query
      ], callback

  removeDeviceFromCache: ({uuid}, callback) =>
    @cache.del uuid, callback

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

  _storeRootTokenInCache: ({token, uuid}, callback) =>
    @cache.set "meshblu-token-cache:#{uuid}:#{token}", '', callback

  _hashObject: (object) =>
    hasher = crypto.createHash 'sha256'
    hasher.update JSON.stringify object
    hasher.digest 'base64'

  _getNewDevice: (properties={}, token, callback) =>
    @rootTokenManager.hash token, (error, hashedToken) =>
      return callback error if error?
      requiredProperties =
        uuid: uuid.v4()
        online: false
        token: hashedToken
        meshblu:
          createdAt: moment().format()
      newDevice = _.extend {}, properties, requiredProperties
      newDevice.meshblu.hash = @_hashObject newDevice
      callback null, newDevice

module.exports = DeviceManager
