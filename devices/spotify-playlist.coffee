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
      @_spotifyID = @config.spotify_id
      @_spotifyType = @config.spotify_type
      @_spotifyContextUri = @config.spotify_uri
      @_shuffle = @config.shuffle
      
      super()
    
    getSpotifyContextUri: () => Promise.resolve(@_spotifyContextUri)
    getShuffle: () => Promise.resolve(@_shuffle)
    
    destroy: () ->
      super()