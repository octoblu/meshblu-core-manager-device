crypto = require 'crypto'
bcrypt = require 'bcrypt'

class RootTokenManager
  generate: =>
    return crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex')

  hash: (token, callback) =>
    bcrypt.hash token, 8, callback

module.exports = RootTokenManager
