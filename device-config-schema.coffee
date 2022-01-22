module.exports = {
  title: "pimatic-spotify Device config schemas"
  SpotifyLogin: {
    title: "Spotify Login device"
    description: "Login Device configuration"
    type: "object"
    extensions: ["xLink", "xOnLabel", "xOffLabel"]
    properties: {
    }
  },
  SpotifyPlayer: {
    title: "Spotify Player Device"
    description: "Spotify Player device configuration"
    type: "object"
    extensions: ["xLink", "xOnLabel", "xOffLabel"]
    properties: {
    }
  },
  SpotifyPlaylist: {
    title: "Spotify playlist Device"
    description: "Spotify Playlist Device configuration"
    type: "object"
    extensions: ["xLink", "xOnLabel", "xOffLabel"]
    properties: {
    }
  }
}