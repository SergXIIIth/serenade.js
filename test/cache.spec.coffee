require './spec_helper'
{Cache} = Serenade

describe 'Serenade.Cache', ->
  beforeEach ->
    class CTOR extends Serenade.Model
      constructor: (@attributes) ->
    @ctor = CTOR
    @uid = @ctor.uniqueId()

  describe '.get', ->
    it 'returns undefined when nothing has been cached', ->
      @ctor.localStorage()
      expect(Cache.get(@ctor, 4)).to.not.exist
    it 'retrieves an object from the identity map', ->
      obj = {}
      Cache.set(@ctor, 4, obj)
      expect(Cache.get(@ctor, 4)).to.eql(obj)
    it 'retrieves an object from the identity map even if it is stored', ->
      @ctor.localStorage()
      obj = {}
      Cache.store(@ctor, 4, 'testing')
      Cache.set(@ctor, 4, obj)
      expect(Cache.get(@ctor, 4)).to.eql(obj)
    it 'returns undefined if the object is stored but local storage is not set', ->
      Cache.store(@ctor, 4, 'testing')
      expect(Cache.get(@ctor, 4)).to.not.exist
    it 'returns the object from cache and inits it with the constructor', ->
      @ctor.localStorage()
      Cache.store(@ctor, 4, { test: 'foo' })
      expect(Cache.get(@ctor, 4).attributes.test).to.eql('foo')
      expect(Cache.get(@ctor, 4).constructor).to.eql(@ctor)

  describe '.store', ->
    it 'stores an object in the local storage engine', ->
      @ctor.localStorage()
      Cache.store(@ctor, 5, 12345)
      expect(Cache._storage.getItem("#{@uid}_5")).to.eql('12345')

    it 'uses a serialize function', ->
      @ctor.localStorage()
      Cache.store(@ctor, 5, { toJSON: -> 456 })
      expect(Cache._storage.getItem("#{@uid}_5")).to.eql('456')

    it 'uses the given name function', ->
      @ctor.localStorage(as: (id) -> "blah-#{id}")
      Cache.store(@ctor, 5, { toJSON: -> 456 })
      expect(Cache._storage.getItem("blah-5")).to.eql('456')

    it 'represents the result as JSON', ->
      @ctor.localStorage()
      Cache.store(@ctor, 5, { toJSON: -> { test: 'foo' }})
      expect(JSON.parse(Cache._storage.getItem("#{@uid}_5")).test).to.eql('foo')

  describe '.retrieve', ->
    it 'retrieves an object from the local storage engine and inits it with constructor', ->
      @ctor.localStorage()
      Cache._storage.setItem("#{@uid}_5", '12345')
      expect(Cache.retrieve(@ctor, 5).attributes).to.eql(12345)

    it 'uses the given name function', ->
      @ctor.localStorage(as: (id) -> "blah-5")
      Cache._storage.setItem("blah-5", '12345')
      expect(Cache.retrieve(@ctor, 5).attributes).to.eql(12345)

    it 'returns undefined if local storage is disabled', ->
      Cache._storage.setItem("#{@uid}_5", '12345')
      expect(Cache.retrieve(@ctor, 5)).to.not.exist
