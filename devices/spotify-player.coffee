module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  
  class SpotifyPlayer extends env.devices.AVPlayer

    constructor: (@config, @plugin, lastState) ->
      @_base = commons.base @, @config.class
      @debug = @plugin.debug || false
      @id = @config.id
      @name = @config.name
      @_spotifyId = @config.spotify_id
      @_spotifyType = @config.spotify_type
      @_defaultVolume = @config.default_volume
      
      @addAttribute 'isActive',
        description: "Spotify device is active",
        type: t.boolean
        discrete: true
      @addAttribute 'isPlaying',
        description: "Spotify device is playing",
        type: t.boolean
        discrete: true
      @addAttribute 'isPrivateSession',
        description: "Spotify device is in a private session",
        type: t.boolean
        discrete: true
      @addAttribute 'isRestricted',
        description: "Spotify device is ar restricted playback device",
        type: t.boolean
        discrete: true
      
      @_isActive = lastState.isActive?.value || false
      @_isPlaying = lastState.isPlaying?.value || false
      @_isPrivateSession = lastState.isPrivateSession?.value || false
      @_isRestricted = lastState.isRestricted?.value || false
      
      super()
      
      @_spotifyApi = () => @plugin.getApi()
      @plugin.on('currentDevice', @_onCurrentDevice)
      @plugin.on('isPlaying', @_onIsPlaying)
      @plugin.on('currentArtist', @_onCurrentArtist)
      @plugin.on('currentTrack', @_onCurrentTrack)
    
    getIsActive: () => Promise.resolve(@_isActive)
    getIsPlaying: () => Promise.resolve(@_isPlaying)
    getIsPrivateSession: () => Promise.resolve(@_isPrivateSession)
    getIsRestricted: () => Promise.resolve(@_isRestricted)
    
    setVolume: (volume = @_defaultVolume) =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi().setVolume(volume, {device_id: @_spotifyId}).then( () =>
          @_base.debug("Playback volume set to: #{volume}")
          resolve()
        
        ).catch( (error) =>
          @_base.rejectWithErrorString Promise.reject, error, "Error setting volume to #{volume}"
        
        )
      )
    
    setShuffle: (shuffle = true) =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi().setShuffle(shuffle, {
          device_id: @_spotifyId
        }).then( () =>
          @_base.debug("Shuffle for current playback set to: #{shuffle}")
          resolve()
          
        ).catch( (error) =>
          @_base.rejectWithErrorString Promise.reject, error, "Error setting shuffle to #{shuffle}"
          
        )
      )
    
    transferPlayback: (start) =>
      return new Promise( (resolve, reject) =>
        return resolve() if @_isActive or @_isPlaying
        @_spotifyApi().transferMyPlayback([@_spotifyId], {
          play: start
        }).then( () =>
          @_base.debug("Playback transferred to: #{@name}")
          resolve()
          
        ).catch( (error) =>
          @_base.rejectWithErrorString Promise.reject, error, "Error transferring playback"
          
        )
      )
    
    play: (context_uri) =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive or @_isPlaying
        @_spotifyApi().play({
          device_id: @_spotifyId
          context_uri: context_uri
        }).then( () =>
          @_base.debug("Started playback on #{@name}")
          resolve()
        
        ).catch( (error) =>
          @_base.rejectWithErrorString Promise.reject, error, "Error starting playback"
          
        )
      )
      
    pause: () =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive or !@_isPlaying
        @_spotifyApi().pause({
          device_id: @_spotifyId
        }).then( () =>
          @_base.debug("Paused playback on #{@name}")
          resolve()
        
        ).catch( (error) =>
          @_base.rejectWithErrorString Promise.reject, error, "Error pausing playback"
          
        )
      )
    
    stop: () => @pause()
      
    previous: () =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi().skipToPrevious({
          device_id: @_spotifyId
        }).then( () =>
          @_base.debug("Skipped to previous song on #{@name}")
          resolve()
          
        ).catch( (error) =>
          @_base.rejectWithErrorString Promise.reject, error, "Error skipping to previous song"
          
        )
      )
    
    next: () =>
      return new Promise( (resolve, reject) =>
        return resolve() if !@_isActive
        @_spotifyApi().skipToNext({
          device_id: @_spotifyId
        }).then( () =>
          @_base.debug("Skipped to next song")
          resolve()
          
        ).catch( (error) =>
          @_base.rejectWithErrorString Promise.reject, error, "Error skipping to next song."
          
        )
      )
    
    _onCurrentDevice: (device) =>
      if device is @_spotifyId
        @_setIsActive(@plugin.getCurrentDevice().is_active)
        @_setIsPrivateSession(@plugin.getCurrentDevice().is_private_session)
        @_setIsRestricted(@plugin.getCurrentDevice().is_restricted)
        @_setVolume(@plugin.getCurrentVolume())
      
      else
        @_clearProperties()
    
    _onIsPlaying: (playing) =>
      if @_isActive
        @_setIsPlaying(playing)
        @_setState(if playing then "play" else "pause")
      
    _onCurrentArtist: (artist) =>
        @_setCurrentArtist(artist) if @_isActive
    
    _onCurrentTrack: (track) =>
        @_setCurrentTitle(track) if @_isActive
    
    _clearProperties: () =>
      @_setIsActive(false)
      @_setIsPrivateSession(false)
      @_setIsRestricted(false)
      @_setVolume(0)
      @_setCurrentArtist("")
      @_setCurrentTitle("")
      @_setState("stop")
      @_setIsPlaying(false)
    
    _setCurrentArtist: (artist) =>
      return if @_currentArtist is artist
      @_base.debug __("currentArtist: %s", artist)
      super(artist)

    _setCurrentTitle: (track) =>
      return if @_currentTitle is track
      @_base.debug __("currentTitle: %s", track)
      super(track)
      
    _setState: (state) =>
      return if @_state is state
      @_base.debug __("state: %s", state)
      super(state)
    
    _setIsPlaying: (bool) =>
      return if @_isPlaying is bool
      @_isPlaying = bool
      @emit('isPlaying', @_isPlaying)
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
    
    destroy: () ->
      @plugin.removeListener('currentDevice', @_onCurrentDevice)
      @plugin.removeListener('isPlaying', @_onIsPlaying)
      @plugin.removeListener('currentArtist', @_onCurrentArtist)
      @plugin.removeListener('currentTrack', @_onCurrentTrack)
    
      super()