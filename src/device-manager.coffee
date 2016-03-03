async = require 'async'
crypto = require 'crypto'
moment = require 'moment'

class DeviceManager
  constructor: ({@datastore,@uuidAliasResolver,@cache}) ->

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

  _hashObject: (object) =>
    hasher = crypto.createHash 'sha256'
    hasher.update JSON.stringify object
    hasher.digest 'base64'

module.exports = DeviceManager
