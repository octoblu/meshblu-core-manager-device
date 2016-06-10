MongoKey = require '../src/mongo-key'

describe 'MongoKey', ->
  describe '->mapKeys', ->
    beforeEach ->
      @returnKey = (obj) =>
        return obj

    describe 'when converting a null object', ->
      beforeEach ->
        @result = MongoKey.mapKeys null, @returnKey

      it 'should return the same object', ->
        expect(@result).to.be.null

    describe 'when converting a false object', ->
      beforeEach ->
        @result = MongoKey.mapKeys false, @returnKey

      it 'should return the same object', ->
        expect(@result).to.be.false

    describe 'when converting an empty object', ->
      beforeEach ->
        @theobject = {}
        @result = MongoKey.mapKeys @theobject, @returnKey

      it 'should return the same object', ->
        expect(@result).to.equal @theobject

    describe 'when converting an object with a falsey object', ->
      beforeEach ->
        @theobject = {
          something: false
          hello: 'hello'
        }
        @result = MongoKey.mapKeys @theobject, @returnKey

      it 'should return the full object', ->
        expect(@result).to.deep.equal {
          something: false
          hello: 'hello'
        }

    describe 'when converting an object with a nested object', ->
      beforeEach ->
        @theobject = {
          something: false
          hello: {
            hello: {
              hello: 'hi'
            }
          }
        }
        @result = MongoKey.mapKeys @theobject, @returnKey

      it 'should return the full object', ->
        expect(@result).to.deep.equal {
          something: false
          hello: {
            hello: {
              hello: 'hi'
            }
          }
        }

    describe 'when converting an object with a collection', ->
      beforeEach ->
        @theobject = {
          something: false
          collection: [
            { hello: 'hi' },
            null,
            { bacon: false }
          ]
        }
        @result = MongoKey.mapKeys @theobject, @returnKey

      it 'should return the full object', ->
        expect(@result).to.deep.equal {
          something: false
          collection: [
            { hello: 'hi' },
            null,
            { bacon: false }
          ]
        }

  describe '->escapeObj', ->
    describe 'when converting an object without any $ keys', ->
      beforeEach ->
        @theobject = {
          something: false
          hello:
            hello: 'hi'
        }
        @result = MongoKey.escapeObj @theobject

      it 'should return the full object', ->
        expect(@result).to.deep.equal {
          something: false
          hello:
            hello: 'hi'
        }

    describe 'when converting an object with multiple $ keys', ->
      beforeEach ->
        obj = {
          something: false
          hello:
            hello: 'hi'
          yes:
            '$foo': 'bar'
          no:
            '$bar': 'foo'
        }
        @result = MongoKey.escapeObj obj

      it 'should return the full object', ->
        escapeChar = '\uFF04'
        expect(@result).to.deep.equal {
          something: false
          hello:
            hello: 'hi'
          yes:
            "#{escapeChar}foo": 'bar'
          no:
            "#{escapeChar}bar": 'foo'
        }

  describe '->unescapeObj', ->
    describe 'when converting an object without any $ keys', ->
      beforeEach ->
        @theobject = {
          something: false
          hello:
            hello: 'hi'
        }
        @result = MongoKey.unescapeObj @theobject

      it 'should return the full object', ->
        expect(@result).to.deep.equal {
          something: false
          hello:
            hello: 'hi'
        }

    describe 'when converting an object with multiple $ keys', ->
      beforeEach ->
        escapeChar = '\uFF04'
        obj = {
          something: false
          hello:
            hello: 'hi'
          yes:
            "#{escapeChar}foo": 'bar'
          no:
            "#{escapeChar}bar": 'foo'
        }
        @result = MongoKey.unescapeObj obj

      it 'should return the full object', ->
        expect(@result).to.deep.equal {
          something: false
          hello:
            hello: 'hi'
          yes:
            "$foo": 'bar'
          no:
            "$bar": 'foo'
        }
