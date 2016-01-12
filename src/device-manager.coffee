class DeviceManager
  constructor: ({@datastore,@uuidAliasResolver}) ->

  findOne: ({uuid}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      query = {uuid}
      @datastore.findOne query, callback

module.exports = DeviceManager
