globalDependencies = {}

triggerGlobal = (target, names) ->
  for name in names
    if globalDependencies.hasOwnProperty(name)
      for { name, type, object, subname, dependency } in globalDependencies[name]
        if type is "singular"
          if target is object[name]
            object[dependency + "_property"]?.triggerChanges?(object)
        else if type is "collection"
          if target in object[name]
            object[dependency + "_property"]?.triggerChanges?(object)

class PropertyDefinition
  constructor: (@name, options) ->
    extend(this, options)

    @dependencies = []
    @localDependencies = []
    @globalDependencies = []

    if @dependsOn
      @addDependency(name) for name in [].concat(@dependsOn)

    @async = if "async" of options then options.async else settings.async

  addDependency: (name) ->
    if @dependencies.indexOf(name) is -1
      @dependencies.push(name)

      if name.match(/\./)
        type = "singular"
        [name, subname] = name.split(".")
      else if name.match(/:/)
        type = "collection"
        [name, subname] = name.split(":")

      @localDependencies.push(name)
      @localDependencies.push(name) if @localDependencies.indexOf(name) is -1
      @globalDependencies.push({ subname, name, type }) if type

class PropertyAccessor
  constructor: (@definition, @object) ->
    @name = @definition.name
    @valueName = "_s_#{@name}_val"

  set: (value) ->
    if typeof(value) is "function"
      @definition.get = value
    else
      if @definition.set
        @definition.set.call(@object, value)
      else
        def @object, @valueName, value: value, configurable: true
      @triggerChanges()

  get: ->
    @registerGlobal()
    if @definition.get
      # add a listener which adds any dependencies that haven't been specified
      listener = (name) => @definition.addDependency(name)
      @object._s_property_access.bind(listener) unless "dependsOn" of @definition
      value = @definition.get.call(@object)
      @object._s_property_access.unbind(listener) unless "dependsOn" of @definition
    else
      value = @object[@valueName]

    @object._s_property_access.trigger(@name)
    value

  format: ->
    if typeof(@definition.format) is "function"
      @definition.format.call(@object, @get())
    else
      @get()

  # Find all properties which are dependent upon this one
  dependents: ->
    deps = []
    findDependencies = (name) =>
      for property in @object._s_properties
        if property.name not in deps and name in property.localDependencies
          deps.push(property.name)
          findDependencies(property.name)
    findDependencies(@name)
    deps

  triggerChanges: ->
    names = [@name].concat(@dependents())
    changes = {}
    changes[name] = @object[name] for name in names
    @object.change.trigger(changes)
    triggerGlobal(@object, names)
    for own name, value of changes
      @object["change_" + name].trigger(value)

  registerGlobal: ->
    unless @object["_glb_" + @name]
      @object["_glb_" + @name] = true
      for { name, type, subname } in @definition.globalDependencies
        globalDependencies[subname] or= []
        globalDependencies[subname].push({ @object, subname, name, type, dependency: @name })

defineProperty = (object, name, options={}) ->
  definition = new PropertyDefinition(name, options)

  safePush(object, "_s_properties", definition)

  defineEvent object, "_s_property_access"
  defineEvent object, "change",
    async: definition.async
    optimize: (queue) ->
      result = {}
      extend(result, item[0]) for item in queue
      [result]
  defineEvent object, "change_" + name,
    async: definition.async
    bind: -> @[name] # make sure dependencies have been discovered and registered
    optimize: (queue) -> queue[queue.length - 1]

  def object, name,
    get: -> @[name + "_property"].get()
    set: (value) -> @[name + "_property"].set(value)
    configurable: true
    enumerable: if "enumerable" of options then options.enumerable else true

  def object, name + "_property",
    get: -> new PropertyAccessor(definition, this)
    configurable: true

  if typeof(options.serialize) is 'string'
    defineProperty object, options.serialize,
      get: -> @[name]
      set: (v) -> @[name] = v
      configurable: true

  object[name] = options.value if "value" of options
