module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  
  class SpotifyPlaylist extends env.devices.PresenceSensor

    constructor: (@config, plugin, lastState) ->
      @_base = commons.base @, @config.class
      @debug = plugin.debug || false
      @id = @config.id
      @name = @config.name
      super()
    
    destroy: () ->
      super()