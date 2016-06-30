_ = require 'lodash'

mapKeys = (obj, convertFn, keysWeActuallyWant) =>
  return obj if _.isEmpty(obj)
  _.each obj, (value, key) =>
    if _.isPlainObject value
      value = mapKeys value, convertFn, keysWeActuallyWant
    if _.isArray value
      value = _.map value, (subvalue) =>
        return mapKeys subvalue, convertFn, keysWeActuallyWant
    delete obj[key]
    convertedKey = convertFn key, keysWeActuallyWant
    obj[convertedKey] = value
    return
  return obj

escape = (key, keysWeActuallyWant) =>
  return key unless _.isString key
  return key if _.includes keysWeActuallyWant, key
  return key.replace(/\$/g, '\uFF04')

unescape = (key) =>
  return key unless _.isString key
  return key.replace(/\uFF04/g, '$')

exports.escapeObj = (obj, keysWeActuallyWant) =>
  return mapKeys obj, escape, keysWeActuallyWant

exports.unescapeObj = (obj) =>
  return mapKeys obj, unescape

exports.unescape = unescape
exports.escape = escape
exports.mapKeys = mapKeys
