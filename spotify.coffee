module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  AuthServer = require('./lib/AuthServer')(env)
  SpotifyWebApi = require('spotify-web-api-node')
  
  
  deviceConfigTemplates = [
    {
      "name": "Spotify Login Device",
      "class": "SpotifyLogin"
    },
    {
      "name": "Spotify Player Device",
      "class": "SpotifyPlayer"
    },
    {
      "name": "Spotify Playlist Device",
      "class": "SpotifyPlaylist"
    }
  ]
  
  actionProviders = [
    'spotify-playlist-action',
    'spotify-volume-action'
  ]
  
  class SpotifyPlugin extends env.plugins.Plugin
    constructor: () ->
      @_accessToken = null
      @_refreshToken = null
      @_expiresIn = null
      @_tokenType = null
      @_playbackState = null
      @_tokenRefreshScheduler = null
      @_playbackRefreshScheduler = null
      
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @_base = commons.base @, 'Plugin'
      
      deviceConfigDef = require("./device-config-schema")
      
      for device in deviceConfigTemplates
        className = device.class
        # convert camel-case classname to kebap-case filename
        filename = className.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase()
        classType = require('./devices/' + filename)(env)
        @_base.debug "Registering device class #{className}"
        @framework.deviceManager.registerDeviceClass(className, {
          configDef: deviceConfigDef[className],
          createCallback: @_callbackHandler(className, classType)
        })
      
      for provider in actionProviders
        className = provider.replace(/(^[a-z])|(\-[a-z])/g, ($1) ->
          $1.toUpperCase().replace('-','')) + 'Provider'
        classType = require('./actions/' + provider)(env)
        @_base.debug "Registering action provider #{className}"
        @framework.ruleManager.addActionProvider(new classType @framework)
      
      @_spotifyApi = new SpotifyWebApi({
        clientId: @config.clientID
        clientSecret: @config.secret
      })
      
      @framework.deviceManager.on('discover', () =>
        return unless @_accessToken?
        @_base.debug("Starting discovery")
        @framework.deviceManager.discoverMessage( 'pimatic-spotify', "Searching for Spotify devices" )
        
        @_spotifyApi.getMyDevices().then( (data) =>
          if data.statusCode is 200
            data.body.devices.map( (device) =>
              @_createPlayerDevice(device)
            )
        
        ).catch( (error) =>
          @_base.error("Error getting my devices: #{error}")
        )
        
        @_spotifyApi.getUserPlaylists().then( (data) =>
          if data.statusCode is 200
            data.body.items.map( (playlist) =>
              @_createPlaylistDevice(playlist)
            )
        
        ).catch( (error) =>
          @_base.error("Error getting my playlists: #{error}")
        )
      )
      
      @authServer = new AuthServer(@config.port, @config.clientID, @config.secret)
      @authServer.on('authorized', @_onAuthorized)
      @authServer.start(@config.auth_port)
    
    getApi: () => return @_spotifyApi
    getCurrentState: () => return @_playbackState
    getCurrentDevice: () => return @_playbackState?.device || null
    getCurrentContext: () => return @_playbackState?.context || null
    getCurrentTrack: () => return @_playbackState?.item || null
    getCurrentVolume: () => return @_playbackState?.device?.volume_percent || null
    getCurrentArtist: () =>
      return null if !@_playbackState?.item?.artists?
      currentArtist = []
      currentArtist.push(artist.name) for artist in @_playbackState.item.artists
      return currentArtist.join(', ')
        
    
    _onAuthorized: (data) =>
      if data?
        @_setAccessToken(data.access_token)
        @_setRefreshToken(data.refresh_token)
        @_setExpiresIn(data.expires_in)
        @_setTokenType(data.token_type)
        
        @_tokenRefreshScheduler = setInterval( @_refreshAccessToken, @_expiresIn / 2 * 1000)
        @_playbackRefreshScheduler = setInterval( @_refreshPlaybackState, 5000 )
      
      else
        @_setAccessToken(null)
        @_setRefreshToken(null)
        @_setExpiresIn(null)
        @_setTokenType(null)
        
        clearInterval(@_tokenRefreshScheduler) if @_tokenRefreshScheduler?
        clearInterval(@_playbackRefreshScheduler) if @_playbackRefreshScheduler?
        @_base.warn("Access token no longer valid!. Please login again")
    
    _refreshAccessToken: () =>
      @_base.debug("Refreshing API access token")
      @_spotifyApi.refreshAccessToken().then( (data) =>
        @_setAccessToken(data.body['access_token'])
        @_setTokenType(data.body['token_type'])
        @_setExpiresIn(data.body['expires_in'])
        @_base.debug('API access token refreshed successfully')
      
      ).catch( (error) =>
        @_base.error("Error refreshing token: #{error}. Please log in again")
      
      )
    
    _refreshPlaybackState: () =>
      @_spotifyApi.getMyCurrentPlaybackState().then( (data) =>
        if data.statusCode is 200
          
          @_setPlaybackState(data.body)
        
        else
          @_setPlaybackState(null)
      )
    
    _setPlaybackState: (data) =>
      if !data?
        @_playbackState = null
        return
      
      artists = []
      artists.push(artist.name) for artist in data.item.artists
      artist = artists.join(', ')
      @_playbackState = data
      
      @emit('playbackState', data)
      @emit('currentDevice', data.device.id)
      @emit('isPlaying', data.is_playing)
      @emit('currentArtist', artist)
      @emit('currentContext', data.context.uri)
      @emit('currentTrack', data.item.name)
        
    _setAccessToken: (token) =>
      return if @_accessToken is token
      @_accessToken = token 
      @_spotifyApi.setAccessToken(token)
      @emit('accessToken', token)
      @_base.debug __("accesToken: %s", token)
    
    _setRefreshToken: (token) =>
      return if @_refreshToken is token
      @_refreshToken = token
      @_spotifyApi.setRefreshToken(token)
      @emit('refreshToken', token)
      @_base.debug __("refreshToken: %s", token)
    
    _setExpiresIn: (expiry) =>
      return if @_expiresIn is expiry
      @_expiresIn = expiry
      @emit('expiresIn', expiry)
      @_base.debug __("expiresIn: %s", expiry)
    
    _setTokenType: (type) =>
      return if @_tokenType is type
      @_tokenType = type
      @emit('tokenType', type)
      @_base.debug __("tokenType: %s", type)
      
    _callbackHandler: (className, classType) ->
      return (config, lastState) =>
        return new classType(config, @, lastState, @framework)
    
    _createPlayerDevice: (device) =>
      @_createDevice({
        class: "SpotifyPlayer"
        name: "Connect Device " + device.name
        id: @_generateId("player-" + device.name)
        spotify_id: device.id
        spotify_type: device.type
      })
      
    _createPlaylistDevice: (playlist) =>
      @_createDevice({
        class: "SpotifyPlaylist"
        name: "Playlist " +  playlist.name
        id: @_generateId("playlist-" + playlist.name)
        spotify_id: playlist.id
        spotify_type: playlist.type
        spotify_uri: playlist.uri
      })
    
    _createDevice: (deviceConfig) =>
      @framework.deviceManager.discoveredDevice('spotify', "#{deviceConfig.name}", deviceConfig)
    
    _generateId: (name) =>
      "spotify-" + name.replace(/[^A-Za-z0-9\-]+/g, '-').toLowerCase()
        
    _destroy: () ->
      @authServer.removeListener('authorized', @_onAuthorized)
  
  return new SpotifyPlugin