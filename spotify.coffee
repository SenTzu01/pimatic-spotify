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
      @apiToken = null
    
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
      
      # auto-discovery
      @framework.deviceManager.on('discover', () =>
        return unless @_apiToken?
        @_base.debug("Starting discovery")
        @framework.deviceManager.discoverMessage( 'pimatic-spotify', "Searching for Spotify devices" )
        
        # device discovery actions, e.g. load players and playlists
      )
      
      @_authServer = new AuthServer(@config.auth_port, @config.clientID, @config.secret)
      @_authServer.on('authorized', @_onAuth)
      @_authServer.on('refresh', @_setApiToken)
      @_authServer.start()
      
    _onAuth: (data) =>
      @_setApiToken(data)
      @_base.debug __("acces_token: %s", data.access_token)
      @_base.debug __("refresh_token: %s", data.refresh_token)
      @_base.debug __("expires_in: %s", data.expires_in)
      @_base.debug __("token_type: %s", data.token_type)
      
      spotifyApi = new SpotifyWebApi()
      spotifyApi.setAccessToken(data.access_token)
      spotifyApi.getMyDevices().then( (data) =>
        console.log(data.body.devices)
      ).catch( (error) =>
        console.log("Error getting my devices: #{error}")
      )
    
    _setApiToken: (data) => @_apiToken = data
    
    _callbackHandler: (className, classType) ->
      # this closure is required to keep the className and classType
      # context as part of the iteration
      return (config, lastState) =>
        return new classType(config, @, lastState, @framework)
    
    
  # Create a instance of my plugin
  # and return it to the framework.
  return new SpotifyPlugin