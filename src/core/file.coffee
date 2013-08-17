fs = require 'fs'
path = require 'path'

_ = require 'lodash'

dirs = require '../utils/dirs'
plugins = require '../utils/plugins'
scan = require '../scanner/scan'

MicroEvent = require '../event/microevent'
Cli = require '../cli'

prefix = "require.register('~path', function(exports, require, module){"
sufix = "}, ~deps);"


module.exports = class File extends MicroEvent

  {argv} = cli = new Cli

  raw: null
  filepath: null
  relativepath: null

  id: null
  type: null
  output: null

  dependents: null
  dependencies: null
  aliases: null

  uncompiled: null
  compiled: null
  map: null

  compiled: null
  src_map: null

  is_partial: no

  compiler: null

  constructor:(@filepath)->
    @relativepath = dirs.relative @filepath
    @compiler = @get_compiler()
    {@type, @output} = @compiler
    @is_partial = @compiler.partials is on and @compiler.is_partial @filepath

  init:->
    @refresh()

  refresh:->
    @raw = fs.readFileSync @filepath, "utf-8"
    @compile =>
      @scan_deps()
      @make_aliases()
      @emit 'refresh:dependents', @dependents
      @wrap()

  compile:( done )->
    @compiler.compile @filepath, @raw, argv.release,
      (err)-> console.log err,
      (@compiled, @map)-> done?(@)

  wrap:->
    if @output is 'css'
      @wrapped = @compiled
    if @output is 'js'
      id = @relativepath.replace @compiler.ext, ''
      @wrapped = prefix.replace '~path', id
      @wrapped += "\n"
      @wrapped += @compiled
      @wrapped += "\n"
      @wrapped += sufix.replace '~deps', JSON.stringify @aliases

  scan_deps:->

    if @type is 'script'
      @dependents = []
      @dependencies = scan.dependencies @filepath, @compiled
      @emit 'new:dependencies', (location for id, location of @dependencies)

    else if (@type is 'template' or @type is 'style')
      @dependencies = []
      return @dependents = [] if not @is_partial
      @dependents = scan.dependents @, @filepath, @compiled

  make_aliases:->
    @aliases = {}
    for id, depath of @dependencies
      @aliases[id] = dirs.relative(depath).replace /\.[^\.]+$/, ''

  get_compiler:->
    for plugin in plugins
      if plugin.ext.test @filepath
        return plugin 