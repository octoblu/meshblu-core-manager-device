_ = require 'lodash'

mapKeys = (obj, convertFn) =>
  return obj if _.isEmpty(obj)
  _.each obj, (value, key) =>
    if _.isPlainObject value
      value = mapKeys value, convertFn
    if _.isArray value
      value = _.map value, (subvalue) =>
        return mapKeys subvalue, convertFn
    delete obj[key]
    convertedKey = convertFn key
    obj[convertedKey] = value
    return
  return obj

escape = (key) =>
  return key unless _.isString key
  return key.replace(/\$/g, '\uFF04')

unescape = (key) =>
  return key unless _.isString key
  return key.replace(/\uFF04/g, '$')

exports.escapeObj = (obj) =>
  return mapKeys obj, escape

exports.unescapeObj = (obj) =>
  return mapKeys obj, unescape

exports.unescape = unescape
exports.escape = escape
exports.mapKeys = mapKeys
