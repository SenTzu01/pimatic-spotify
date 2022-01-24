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
      
      @_spotifyID = @config.spotify_id
      @_spotifyType = @config.spotify_type
      @_spotifyContextUri = @config.spotify_uri
      @_shuffle = @config.shuffle
      
      @_updateScheduler = null
      @_interval = 5000
      
      @plugin.on('accessToken', @_onAccessToken)
      
      super()
    
    getSpotifyContextUri: () => Promise.resolve(@_spotifyContextUri)
    getShuffle: () => Promise.resolve(@_shuffle)
    
    _onAccessToken: (token) =>
      if token?
        @_update()
          .then( () =>
            @_updateScheduler = setInterval(@_update, @_interval)
            Promise.resolve
          ).catch( (error) =>
            @_base.rejectWithErrorString Promise.reject, error, "Error updating device: #{error}"
          )
      
      else
        clearInterval(@_updateScheduler) if @_updateScheduler?
        @_setPresence(false)
     
    _update: () =>
      return new Promise( (resolve, reject) =>
        devices = _(@_framework.deviceManager.devices).values().filter( (device) => 
            device.config.class is 'SpotifyPlayer' and device.isPlaying() and device.getContextUri() is @_spotifyContextUri
        ).value()
        
        @_setPresence(devices.length > 0)
        resolve()
      )
    
    _setPresence: (presence) =>
      return if @_presence is presence
      @_base.debug __("presence: %s", presence)
      super(presence)
    
    destroy: () ->
      clearInterval(@_updateScheduler)
      @plugin.removeListener('accessToken', @_onAccessToken)
      super()