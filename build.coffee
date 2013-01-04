{Serenade} = require './src/serenade'

CoffeeScript = require 'coffee-script'
fs = require 'fs'
path = require 'path'
gzip = require 'gzip'

sys = require('sys')
exec = require('child_process').exec


header = (cb) ->
  exec "git rev-parse HEAD", (error, stdout, stderr) ->
    cb """
      /**
       * Serenade.js JavaScript Framework v#{Serenade.VERSION}
       * Revision: #{stdout.slice(0, 10)}
       * http://github.com/elabs/serenade.js
       *
       * Copyright 2011, Jonas Nicklas, Elabs AB
       * Released under the MIT License
       */
    """

Build =
  files: ->
    files = {}
    sourceFiles = fs.readdirSync 'src'
    for name in sourceFiles when name.match(/\.coffee$/)
      content = fs.readFileSync('src/' + name).toString()
      files[name.replace(/\.coffee$/, "")] = CoffeeScript.compile(content, bare: false)
    files["parser"] = Build.parser()
    files

  parser: -> require('./src/grammar').Parser.generate()

  compile: (callback) ->
    files = Build.files()
    requires = ''
    for name in ['helpers', 'event', 'cache', 'collection', 'association_collection', 'property', 'model', 'serenade', 'lexer', 'node', 'dynamic_node', 'compile', 'parser', 'view']
      requires += """
        require['./#{name}'] = new function() {
          var exports = this;
          #{files[name]}
        };
      """
    callback """
      (function(root) {
        var Serenade = function() {
          function require(path){ return require[path]; }
          #{requires}
          return require['./serenade'].Serenade
        }();

        if(typeof define === 'function' && define.amd) {
          define(function() { return Serenade });
        } else { root.Serenade = Serenade }
      }(this));
    """

  unpacked: (callback) ->
    header (header) ->
      Build.compile (code) -> callback(header + '\n' + code)

  minified: (callback) ->
    header (header) ->
      Build.compile (code) ->
        {parser, uglify} = require 'uglify-js'
        minified = uglify.gen_code uglify.ast_squeeze uglify.ast_mangle parser.parse code
        callback(header + "\n" + minified)

  gzipped: (callback) ->
    Build.minified (minified) ->
      gzip (minified), (err, data) ->
        callback(data)

exports.Build = Build
