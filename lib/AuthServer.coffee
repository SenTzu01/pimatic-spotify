module.exports = (env) ->

  Promise = env.require('bluebird')
  events = require('events')
  commons = require('pimatic-plugin-commons')(env)
  SpotifyWebApi = require('spotify-web-api-node')
  express = require('express')
  
  class AuthServer extends events.EventEmitter
  
    constructor: (port, clientId, clientSecret) ->
      ipAddress = null
      @_port = port || 8888
      @_loginPath = '/login'
      callbackPath = '/callback'
      scopes = [
        'ugc-image-upload',
        'user-read-playback-state',
        'user-modify-playback-state',
        'user-read-currently-playing',
        'streaming',
        'app-remote-control',
        'user-read-email',
        'user-read-private',
        'playlist-read-collaborative',
        'playlist-modify-public',
        'playlist-read-private',
        'playlist-modify-private',
        'user-library-modify',
        'user-library-read',
        'user-top-read',
        'user-read-playback-position',
        'user-read-recently-played',
        'user-follow-read',
        'user-follow-modify'
      ]
      
      spotifyApi = new SpotifyWebApi({clientId, clientSecret})
      
      @_app = express()
      @_app.get(@_loginPath, (req, res) =>
        ipAddress = req.connection.localAddress.match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)[0]
        spotifyApi.setRedirectURI("http://#{ipAddress}:#{@_port}#{callbackPath}")
        res.redirect(spotifyApi.createAuthorizeURL(scopes))
      
      )
      
      @_app.get(callbackPath, (req, res) =>
        error = req.query.error
        code = req.query.code
        state = req.query.state
        env.logger.debug("Auth code: #{code}")
        if error
          env.logger.error('Callback Error:', error)
          res.send("Callback Error: #{error}")
          return
        
        spotifyApi.authorizationCodeGrant(code).then( (data) =>
          access_token = data.body['access_token']
          refresh_token = data.body['refresh_token']
          expires_in = data.body['expires_in']
          
          spotifyApi.setAccessToken(access_token)
          spotifyApi.setRefreshToken(refresh_token)
          @emit('authorized', data.body)
          env.logger.debug("Successfully retrieved access token. Expires in #{expires_in} s.")
          
          res.send('Success! You can now close this window.')
          spotifyApi = undefined
        
        ).catch( (error) =>
          env.logger.error('Error getting Tokens:', error)
          res.send("Error getting Tokens: #{error}")
        )
      )
      
    start: () =>
      @_app.listen(@_port, () =>
        env.logger.warn("To authorize the Pimatic Spotify plugin, use a browser and go to http://<serverIP>:#{@_port}#{@_loginPath}")
      )
        
    destroy: () =>
      super()