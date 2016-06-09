exports.escape = (key) =>
  return key.replace(/\$/g, '\uFF04')

exports.unescape = (key) =>
  return key.replace(/\uFF04/g, '$')
