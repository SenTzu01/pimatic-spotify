module.exports = (env) ->

  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  M = env.matcher
  _ = env.require('lodash')
  assert = env.require 'cassert'
  
  class SpotifyStatePredicateProvider extends env.predicates.PredicateProvider
    constructor: (@framework, @plugin) ->
      @debug = @plugin.config.debug ? false
      @base = commons.base @, "SpotifyStatePredicateProvider"

    parsePredicate: (input, context) ->
      devices = _(@framework.deviceManager.devices).values()
        .filter((device) => device.config.class is 'SpotifyPlayer').value()

      device = null
      state = null
      negated = null
      match = null

      M(input, context)
        .match(['state of '])
        .matchDevice(devices, (next, d) =>   
          next.match([' is', ' reports', ' signals'])
            .match([' playing', ' stopped',' paused', ' not playing'], (m, s) =>
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              mapping = {'playing': 'play', 'stopped': 'stop', 'paused': 'pause', 'not playing': 'not play'}
              state = mapping[s.trim()] # is one of  'playing', 'stopped', 'paused', 'not playing'

              match = m.getFullMatch()
            )
      )

      if match?
        assert device?
        assert state?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new SpotifyStatePredicateHandler(device, state, @plugin)
        }
      else
        return null

  class SpotifyStatePredicateHandler extends env.predicates.PredicateHandler

    constructor: (@device, @state, plugin) ->
      @debug = plugin.config.debug ? false
      @base = commons.base @, "SpotifyStatePredicateHandler"
      @dependOnDevice(@device)

    setup: ->
      @playingListener = (p) =>
        @base.debug "Checking if current state #{p} matches #{@state}"
        if @state is p or (@state is 'not play' and p isnt 'play')
          @emit 'change', true

      @device.on 'state', @playingListener
      super()

    getValue: ->
      return @device.getUpdatedAttributeValue('state').then(
        (p) =>
          @state is p or (@state is 'not play' and p isnt 'play')
      )

    destroy: ->
      @device.removeListener 'state', @playingListener
      super()

    getType: -> 'state'
    
  return SpotifyStatePredicateProvider