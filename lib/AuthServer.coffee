module.exports = (env) ->

  Promise = env.require('bluebird')
  events = require('events')
  commons = require('pimatic-plugin-commons')(env)
  SpotifyWebApi = require('spotify-web-api-node')
  express = require('express')
  
  class AuthServer extends events.EventEmitter
  
    constructor: (@_port = 8888, @_client_id, @_client_secret) ->
      redirectURI = null
      
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
      console.log(@_client_secret)
      spotifyApi = new SpotifyWebApi({
        clientId: @_client_id
        clientSecret: @_client_secret
      })
      @_app = express()
      
      @_app.get('/login', (req, res) =>
        IPv4Address = req.connection.localAddress.match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)[0]
        @_redirectURI = __("http://%s:%s/callback", IPv4Address, @_port)
        
        spotifyApi.setRedirectURI(@_redirectURI)
        res.redirect(spotifyApi.createAuthorizeURL(scopes))
      )
      
      @_app.get('/callback', (req, res) =>
        error = req.query.error
        code = req.query.code
        console.log code
        state = req.query.state
        
        if error
          console.error('Callback Error:', error)
          res.send("Callback Error: #{error}")
          return
        
        spotifyApi.authorizationCodeGrant(code).then( (data) =>
          access_token = data.body['access_token']
          refresh_token = data.body['refresh_token']
          expires_in = data.body['expires_in']
          
          @emit('authorized', data.body)
          console.log('access_token: ', access_token)
          console.log('refresh_token: ', refresh_token)
          console.log("Successfully retrieved access token. Expires in #{expires_in} s.")
          
          res.send('Success! You can now close this window.')
          
          refresh = () =>
            spotifyApi.refreshAccessToken().then( (data) =>
              access_token = data.body['access_token']
              console.log("refreshed access token: #{access_token}")
              @emit('refresh', data.body)
              console.log('The access token has been refreshed!')
              console.log('access_token:', access_token)
              spotifyApi.setAccessToken(access_token)
            ).catch( (error) =>
              console.log("Error refreshing token: #{error}")
            )
            
          setInterval( refresh, expires_in / 2 * 1000)
            
              
        ).catch( (error) =>
          console.error('Error getting Tokens:', error)
          res.send("Error getting Tokens: #{error}")
        )
      )
      
    start: () =>
      @_app.listen(@_port, () =>
        console.log __("To authorize the Pimatic Spotify plugin, use a browser and go to http://<server ip>:#{@_port}/login")
      )
        
    destroy: () =>
      super()