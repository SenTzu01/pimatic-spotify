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
    'spotify-playlist-action'
  ]
  
  # ###Spotify Plugin class
  class SpotifyPlugin extends env.plugins.Plugin
    constructor: () ->
      @_accessToken = null
      @_refreshToken = null
      @_expiresIn = null
      @_tokenType = null
      
      @_updateScheduler = null
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @_base = commons.base @, 'Plugin'
      
      # register devices
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
      
      # register actions
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
      
      # auto-discovery
      @framework.deviceManager.on('discover', () =>
        return unless @_accessToken?
        @_base.debug("Starting discovery")
        @framework.deviceManager.discoverMessage( 'pimatic-spotify', "Searching for Spotify devices" )
        # device discovery actions, e.g. load players and playlists
        
        @_spotifyApi.getMyDevices().then( (data) =>
          data.body.devices.map( (device) =>
            if @debug
              util = env.require('util')
              @_base.debug(util.inspect(device))
            @_createPlayerDevice(device)
          )
        
        ).catch( (error) =>
          @_base.error("Error getting my devices: #{error}")
        )
        
        @_spotifyApi.getUserPlaylists().then( (data) =>
          data.body.items.map( (playlist) =>
            if @debug
              util = env.require('util')
              @_base.debug(util.inspect(playlist))
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
    
    _onAuthorized: (data) =>
      if data?
        @setAccessToken(data.access_token)
        @setRefreshToken(data.refresh_token)
        @setExpiresIn(data.expires_in)
        @setTokenType(data.token_type)
             
        @_updateScheduler = setInterval( @refreshToken, @_expiresIn / 2 * 1000)
      
      else
        @setAccessToken(null)
        @setRefreshToken(null)
        @setExpiresIn(null)
        @setTokenType(null)
        
        clearInterval(@_updateScheduler) if @_updateScheduler?
        @_base.warn("Access token no longer valid!. Please login again")
    
    refreshToken: () =>
      @_base.debug("Refreshing API access token")
      @_spotifyApi.refreshAccessToken().then( (data) =>
        @setAccessToken(data.body['access_token'])
        @setTokenType(data.body['token_type'])
        @setExpiresIn(data.body['expires_in'])
        @_base.debug('API access token refreshed successfully')
      
      ).catch( (error) =>
        @_base.error("Error refreshing token: #{error}. Please log in again")
      
      )
    
    setAccessToken: (token) =>
      return if @_accessToken is token
      @_accessToken = token
      @_spotifyApi.setAccessToken(@_accessToken)
      @emit('accessToken', @_accessToken)
      @_base.debug __("accesToken: %s", @_accessToken)
    
    setRefreshToken: (token) =>
      return if @_refreshToken is token
      @_refreshToken = token
      @_spotifyApi.setRefreshToken(@_refreshToken)
      @emit('refreshToken', @_refreshToken)
      @_base.debug __("refreshToken: %s", @_refreshToken)
    
    setExpiresIn: (expiry) =>
      return if @_expiresIn is expiry
      @_expiresIn = expiry
      @emit('expiresIn', @_expiresIn)
      @_base.debug __("expiresIn: %s", @_expiresIn)
    
    setTokenType: (type) =>
      return if @_tokenType is type
      @_tokenType = type
      @emit('tokenType', @_tokenType)
      @_base.debug __("tokenType: %s", @_tokenType)
      
    _callbackHandler: (className, classType) ->
      # this closure is required to keep the className and classType
      # context as part of the iteration
      return (config, lastState) =>
        return new classType(config, @, lastState, @framework)
    
    _createPlayerDevice: (device) =>
      deviceConfig = {
        class: "SpotifyPlayer"
        name: device.name
        id: "spotify-player-" +  device.name.replace(/ /g, '-').toLowerCase()
        spotify_id: device.id
        spotify_type: device.type
      }
      
      @framework.deviceManager.discoveredDevice('spotify-player', "#{deviceConfig.name}", deviceConfig)
      
    _createPlaylistDevice: (playlist) =>
      
      deviceConfig = {
        class: "SpotifyPlaylist"
        name: playlist.name
        id: "spotify-player-" + playlist.name.replace(/ /g, '-').toLowerCase()
        spotify_id: playlist.id
        spotify_type: playlist.type
        spotify_uri: playlist.uri
      }
      
      @framework.deviceManager.discoveredDevice('spotify-playlist', "#{deviceConfig.name}", deviceConfig)
      
      
  # Create a instance of my plugin
  # and return it to the framework.
  return new SpotifyPlugin