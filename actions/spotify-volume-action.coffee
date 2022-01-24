module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  commons = require('pimatic-plugin-commons')(env)
  _ = env.require 'lodash'
  M = env.matcher
  
  class SpotifyVolumeActionProvider extends env.actions.ActionProvider
    constructor: (@framework) ->
      super()

    parseAction: (input, context) =>
      
      devices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class is 'SpotifyPlayer'
      ).value()
      
      match = null
      player = null
      volume = null

      
      # Try to match the input string with:
      M(input, context)
        .match('set volume of ')
        .matchDevice(devices, (next, d) =>
          next.match(' to ')
            .matchNumericExpression( (next, ts) =>
              m = next.match('%', optional: yes)
              if player? and player.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              player = d
              volume = ts
              match = m.getFullMatch()
            )
        )
      
      if match?
        assert player?
        assert volume?
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new SpotifyVolumeActionHandler(@framework, player, volume)
        }
      else
        return null
  
  class SpotifyVolumeActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @_player, @_volume) ->
      @_base = commons.base @
      super()

    setup: ->
      @dependOnDevice(@_player)
      super()

    executeAction: (simulate) =>
      @_play(simulate)

    _play: (simulate) =>
      @framework.variableManager.evaluateNumericExpression(@_volume).then( (volume) =>
        if simulate
          return Promise.resolve(__("Would set volume of: '%s' to %s"), @_player.name, volume)
        else
          @_player.setVolume(volume)
          .then( () =>
            return Promise.resolve(__("Set volume of %s to %s", @_player.name, volume))
          )
      )
  
  return SpotifyVolumeActionProvider
