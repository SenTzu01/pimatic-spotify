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
      
      )
      
      @_authServer = new AuthServer(@config.port, @config.clientID, @config.secret)
      @_authServer.on('authorized', @_onAuthorized)
      @_authServer.start(@config.auth_port)
    
    getApi: () => return @_spotifyApi
    
    _onAuthorized: (data) =>
      @setAccessToken(data.access_token)
      @setRefreshToken(data.refresh_token)
      @setExpiresIn(data.expires_in)
      @setTokenType(data.token_type)
      
      @_spotifyApi.setAccessToken(@_accessToken)
      @_spotifyApi.setRefreshToken(@_refreshToken)
            
      setInterval( @refreshToken, @_expiresIn / 2 * 1000)
    
    refreshToken: () =>
      @_base.debug("Refreshing API access token")
      @_spotifyApi.refreshAccessToken().then( (data) =>
        @setAccessToken(data.body['access_token'])
        @_spotifyApi.setAccessToken(@_accessToken)
        @_base.debug('API access token refreshed successfully')
      
      ).catch( (error) =>
        @_base.error("Error refreshing token: #{error}. Please log in again")
      
      )
    
    setAccessToken: (token) =>
      return if @_accessToken is token
      @_accessToken = token
      @emit('accessToken', @_accessToken)
      @_base.debug __("accesToken: %s", @_accessToken)
    
    setRefreshToken: (token) =>
      return if @_refreshToken is token
      @_refreshToken = token
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
        id: "spotify-player-#{device.name}"
        spotify_id: device.id
        spotify_type: device.type
      }
      
      @framework.deviceManager.discoveredDevice('spotify-player', "#{deviceConfig.name}", deviceConfig)
      
    _createPlaylistDevice: (device) =>
    
  # Create a instance of my plugin
  # and return it to the framework.
  return new SpotifyPlugin