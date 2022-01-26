module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  
  class SpotifyPlaylist extends env.devices.PresenceSensor

    constructor: (@config, @plugin, lastState, @_framework) ->
      @_base = commons.base @, @config.class
      @debug = @plugin.debug || false
      @id = @config.id
      @name = @config.name
      
      @_spotifyId = @config.spotify_id
      @_spotifyType = @config.spotify_type
      @_spotifyUri = @config.spotify_uri
      @_shuffle = @config.shuffle
      
      super()
      
      @plugin.on('currentContext', @_onCurrentContext)
    
    getSpotifyUri: () => Promise.resolve(@_spotifyUri)
    getShuffle: () => Promise.resolve(@_shuffle)
    
    _onCurrentContext: (uri) =>
        @_setPresence(uri is @_spotifyUri)
    
    _setPresence: (presence) =>
      return if @_presence is presence
      @_base.debug __("presence: %s", presence)
      super(presence)
    
    destroy: () ->
      @plugin.removeListener('currentContext', @_onCurrentContext)
      super()