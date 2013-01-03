{Collection} = require './collection'
{Property, defineProperty} = require("./property")
{AssociationCollection} = require './association_collection'
{Events} = require './events'
{prefix, pairToObject, serializeObject, extend} = require './helpers'

exp = /^_prop_/

globalDependencies = {}

addGlobalDependencies = (object, dependency, names) ->
  unless object["_glb_" + dependency]
    object["_glb_" + dependency] = true
    for name in names
      if name.match(/\./)
        type = "singular"
        [name, subname] = name.split(".")
      else if name.match(/:/)
        type = "collection"
        [name, subname] = name.split(":")

      if subname
        globalDependencies[subname] or= []
        globalDependencies[subname].push({ object, dependency, subname, name, type })

addDependencies = (object, dependency, names) ->
  names = [].concat(names)
  for name in names
    [name, subname] = name.split(/[:\.]/) if name.match(/[:\.]/)
    object["_dep_" + name] ||= []
    object["_dep_" + name].push(dependency) if dependency not in object["_dep_" + name]

triggerGlobal = (object, names) ->
  for name in names
    if globalDependencies[name]
      for dependency in globalDependencies[name]
        if dependency.type is "singular"
          if object is dependency.object.get(dependency.name)
            triggerChangesTo(dependency.object, [dependency.dependency])
        else if dependency.type is "collection"
          if object in dependency.object.get(dependency.name)
            triggerChangesTo(dependency.object, [dependency.dependency])


triggerChangesTo = (object, names) ->
  findDependencies = (name) ->
    dependencies = object["_dep_" + name]
    if dependencies
      for dependency in dependencies
        if dependency not in names
          names.push(dependency)
          findDependencies(dependency)
  findDependencies(name) for name in names

  changes = {}
  changes[name] = object.get(name) for name in names
  object.trigger("change", changes)
  triggerGlobal(object, names)
  for own name, value of changes
    object.trigger("change:#{name}", value)

Properties =
  property: (name, options={}) ->
    defineProperty(this, name, options)
    if typeof(options.serialize) is 'string'
      @property options.serialize,
        get: -> @get(name)
        set: (v) -> @set(name, v)
        configurable: true

  collection: (name, options={}) ->
    extend options,
      get: ->
        unless @attributes[name]
          @attributes[name] = new Collection([])
          @attributes[name].bind 'change', =>
            triggerChangesTo(this, [name])
        @attributes[name]
      set: (value) ->
        @get(name).update(value)
    @property name, options

  toJSON: ->
    serialized = {}
    for name, options of this when name.match(exp)
      if typeof(options.serialize) is 'string'
        serialized[options.serialize] = serializeObject(@get(options.name))
      else if typeof(options.serialize) is 'function'
        [key, value] = options.serialize.call(@)
        serialized[key] = serializeObject(value)
      else if options.serialize
        serialized[options.name] = serializeObject(@get(options.name))
    serialized

extend(Properties, Events)

Associations =
  belongsTo: (name, attributes={}) ->
    extend attributes,
      set: (model) ->
        if model and model.constructor is Object and attributes.as
          model = new (attributes.as())(model)
        previous = @attributes[name]
        @attributes[name] = model
        if attributes.inverseOf and not model[attributes.inverseOf].includes(this)
          previous[attributes.inverseOf].delete(this) if previous
          model[attributes.inverseOf].push(this)
    @property name, attributes
    @property name + 'Id',
      get: -> @get(name)?.id
      set: (id) -> @set(name, attributes.as().find(id)) if id?
      dependsOn: name
      serialize: attributes.serializeId

  hasMany: (name, attributes={}) ->
    extend attributes,
      get: ->
        unless @attributes[name]
          @attributes[name] = new AssociationCollection(this, attributes, [])
          @attributes[name].bind 'change', => triggerChangesTo(this, [name])
        @attributes[name]
      set: (value) ->
        @get(name).update(value)
    @property name, attributes
    @property name + 'Ids',
      get: -> new Collection(@get(name)).map((item) -> item?.id)
      set: (ids) ->
        objects = (attributes.as().find(id) for id in ids)
        @get(name).update(objects)
      dependsOn: name
      serialize: attributes.serializeIds

exports.Properties = Properties
exports.Associations = Associations
exports.globalDependencies = globalDependencies
