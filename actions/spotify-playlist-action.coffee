module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  commons = require('pimatic-plugin-commons')(env)
  _ = env.require 'lodash'
  M = env.matcher
  
  class SpotifyPlaylistActionProvider extends env.actions.ActionProvider
    constructor: (@framework) ->
      super()

    parseAction: (input, context) =>
      
      playlistDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class is 'SpotifyPlaylist'
      ).value()
      
      playerDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class is 'SpotifyPlayer'
      ).value()
      
      playlist = null
      player = null
      match = null
      valueTokens = null

      
      # Try to match the input string with: set ->
      m = M(input, context).match(['play '])
      
      m.matchDevice( playlistDevices, (m, d) ->
        # Already had a match with another device?
        if playlistDevice? and playlistDevice.id isnt d.id
          context?.addError(""""#{input.trim()}" is ambiguous.""")
          return
        playlist = d
      
        m.match(' on ', (m) ->
          m.matchDevice( playerDevices, (m, d) ->
            # Already had a match with another device?
            if playerDevice? and playerDevice.id isnt d.id
              context?.addError(""""#{input.trim()}" is ambiguous.""")
              return
            player = d
            match = m.getFullMatch()
          )
        )
      )
      
      if match?
        assert playlist?
        assert player?
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new SpotifyPlaylistActionHandler(@framework, playlist, player)
        }
      else
        return null
  
  class SpotifyPlaylistActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @_playlist, @_player) ->
      @_base = commons.base @
      super()

    setup: ->
      @dependOnDevice(@_playlist)
      @dependOnDevice(@_player)
      super()

    executeAction: (simulate) =>
      @_play(simulate)

    _play: (simulate) =>
      if simulate
        return Promise.resolve(__("Would play: '%s' on %s"), @_playlist.name, @_player.name)
      else
        @_playlist.getShuffle()
          .then( (shuffle) =>
            @_player.setShuffle(shuffle)
          ).then( () =>
            @_player.setVolume()
          ).then( () =>
            @_playlist.getSpotifyContextUri()
          ).then( (uri) =>
            @_player.playContent(uri)
          )
        
        return Promise.resolve(__("Playing %s on %s", @_playlist.name, @_player.name))
        
  
  return SpotifyPlaylistActionProvider
