module.exports = {
  title: "pimatic-spotify plugin config options"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
    clientID:
      description: "The Spotify API App ID"
      type: "string"
      required: true
    secret:
      description: "The Spotify API App secret"
      type: "string"
      required: true
    auth_port:
      description: "TCP port for the authorization HTTP server to listen on"
      type: "number"
      default: 8888
}