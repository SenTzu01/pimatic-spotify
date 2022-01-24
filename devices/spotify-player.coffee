module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  
  class SpotifyPlayer extends env.devices.AVPlayer

    constructor: (@config, @plugin, lastState) ->
      @_base = commons.base @, @config.class
      @debug = @plugin.debug || false
      @id = @config.id
      @name = @config.name
      @spotifyId = @config.spotify_id
      @spotifyType = @config.spotify_type
      @_defaultVolume = @config.default_volume
      @_state = lastState.state?.value || false
      @_isActive = lastState.isActive?.value || false
      @_isPlaying = lastState.isPlaying?.value || false
      @_isPrivateSession = lastState.isPrivateSession?.value || false
      @_isRestricted = lastState.isRestricted?.value || false
      @_contextUri = lastState.contextUri?.value || null
      @_updateScheduler = null
      @_interval = 5000
      
      @_spotifyApi = () => @plugin.getApi()
      @plugin.on('accessToken', @_onAccessToken)
      super()
    
    getContextUri: () => return @_contextUri
    isPlaying: () => return @_isPlaying
    
    setVolume: (volume = @_defaultVolume) =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi()
          .setVolume(volume)
          .then( () =>
            @_base.debug("Volume set to #{volume} on #{@name}")
            @_update()
            
          )
          .then( () =>
            resolve()
          
          )
          .catch( (error) =>
            #if the user making the request is non-premium, a 403 FORBIDDEN response code will be returned
            @_base.rejectWithErrorString Promise.reject, error, "Error setting volume."
          
          )
      )
    
    setShuffle: () =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi()
          .setShuffle(true)
          .then( () =>
            @_base.debug("Shuffle enabled.")
            @_update()
            
          )
          .then( () =>
            resolve()
          
          )
          .catch( (error) =>
            #if the user making the request is non-premium, a 403 FORBIDDEN response code will be returned
            @_base.rejectWithErrorString Promise.reject, error, "Error setting volume."
          
          )
      )
    
    transferPlayback: () =>
      return new Promise( (resolve, reject) =>
        return resolve() if @_isActive
        @_spotifyApi()
          .transferMyPlayback([@spotifyId])
          .then( () =>
            @_base.debug("playback transferred to: #{@name}")
            resolve()
          
          )
          .catch( (error) =>
            #if the user making the request is non-premium, a 403 FORBIDDEN response code will be returned
            @_base.rejectWithErrorString Promise.reject, error, "Error starting playback."
          
          )
      )
    
    playContent: (context_uri) => 
      @play({context_uri})
    
    play: (options = {}) =>
      return new Promise( (resolve, reject) =>
        @transferPlayback()
          .then( () =>
            @_spotifyApi().play(options)  
          
          )
          .then( () =>
            @_base.debug("Started playback on #{@name}")
            @_update()
            
          )
          .then( () =>
            resolve()
          
          )
          .catch( (error) =>
            #if the user making the request is non-premium, a 403 FORBIDDEN response code will be returned
            @_base.rejectWithErrorString Promise.reject, error, "Error starting playback."
            
          )
        )
      
    pause: () =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi()
          .pause()
          .then( () =>
            @_base.debug("Playback paused on #{@name}")
            @_update()
            
          )
          .then( () =>
            resolve()
          
          ).catch( (error) =>
            #if the user making the request is non-premium, a 403 FORBIDDEN response code will be returned
            @_base.rejectWithErrorString Promise.reject, error, "Error pausing playback."
          
          )
      )
    
    stop: () => @pause()
      
    previous: () =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi()
          .skipToPrevious()
          .then( () =>
            @_base.debug("Skipped to previous song on #{@name}")
            @_update()
            
          )
          .then( () =>
            resolve()
          
          ).catch( (error) =>
            #if the user making the request is non-premium, a 403 FORBIDDEN response code will be returned
            @_base.rejectWithErrorString Promise.reject, error, "Error skipping to previous song."
          
          )
      )
    
    next: () =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi()
          .skipToNext()
            .then( () =>
              @_base.debug("Skipped to next song on #{@name}")
              @_update()
            
            )
            .then( () =>
              resolve()
              
            ).catch( (error) =>
              #if the user making the request is non-premium, a 403 FORBIDDEN response code will be returned
              @_base.rejectWithErrorString Promise.reject, error, "Error skipping to next song."
          
            )
      )
    
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
        @_setIsActive(false)
        @_setIsPrivateSession(false)
        @_setIsRestricted(false)
        @_setVolume(0)
        @_setContextUri("")
        @_setCurrentArtist("")
        @_setCurrentTitle("")
        @_setState("stop")
        @_setIsPlaying(false)
        Promise.resolve
    
    _update: () =>
      return new Promise( (resolve, reject) =>
        @_spotifyApi()
        .getMyCurrentPlaybackState()
          .then( (data) =>
            if data.statusCode is 200 and data.body?.device?.id is @spotifyId
              @_base.debug("Updating properties")
              details = data.body
              currentArtist = []
              currentArtist.push(artist.name) for artist in data.body.item.album.artists
              @_setIsActive(data.body.device.is_active)
              @_setIsPrivateSession(data.body.device.is_private_session)
              @_setIsRestricted(data.body.device.is_restricted)
              @_setVolume(data.body.device.volume_percent)
              @_setContextUri(data.body.context.uri)
              @_setCurrentArtist(currentArtist.join(", "))
              @_setCurrentTitle(data.body.item.name)
              @_setIsPlaying(data.body.is_playing)
              state = if data.body.is_playing then "play" else "pause"
              @_setState(state)
            
            else
              @_base.debug("Device is not active or general error. Clearing properties")
              @_setIsActive(false)
              @_setIsPrivateSession(false)
              @_setIsRestricted(false)
              @_setVolume(0)
              @_setContextUri("")
              @_setCurrentArtist("")
              @_setCurrentTitle("")
              @_setState("stop")
              @_setIsPlaying(false)
            resolve()
          
          ).catch( (error) =>
            @_base.rejectWithErrorString Promise.reject, error, "Error getting device details from Spotify: #{error}"
          )
      )
    
    _setCurrentArtist: (artist) =>
      return if @_currentArtist is artist
      @_base.debug __("currentArtist: %s", artist)
      super(artist)

    _setCurrentTitle: (title) =>
      return if @_currentTitle is title
      @_base.debug __("currentTitle: %s", title)
      super(title)
      
    _setState: (state) =>
      return if @_state is state
      @_base.debug __("state: %s", state)
      super(state)
    
    _setIsPlaying: (bool) =>
      return if @_isPlaying is bool
      @_isPlaying = bool
      @emit('isPlaying', {
        @_isPlaying
        @_contextUri
      })
      @_base.debug __("isPlaying: %s", @_isPlaying)
      
    _setIsActive: (bool) =>
      return if @_isActive is bool
      @_isActive = bool
      @emit('isActive', @_isActive)
      @_base.debug __("isActive: %s", @_isActive)
    
    _setIsPrivateSession: (bool) =>
      return if @_isPrivateSession is bool
      @_isPrivateSession = bool
      @emit('isActive', @_isPrivateSession)
      @_base.debug __("isPrivateSession: %s", @_isPrivateSession)
    
    _setIsRestricted: (bool) =>
      return if @_isRestricted is bool
      @_isRestricted = bool
      @emit('isRestricted', @_isRestricted)
      @_base.debug __("isRestricted: %s", @_isRestricted)
    
    _setContextUri: (uri) =>
      return if @_contextUri is uri
      @_contextUri = uri
      @emit('contextUri', @_contextUri)
      @_base.debug __("contextUri: %s", @_contextUri)
    
    destroy: () ->
      clearInterval(@_updateScheduler)
      @plugin.removeListener('accessToken', @_onAccessToken)
      super()