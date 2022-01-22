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
      spotify_id:
        description: "The Spotify ID of your player"
        type: "string"
        required: true
      spotify_type:
        description: "The Spotify Type of your player"
        enum: [
          "Computer",
          "Tablet",
          "Smartphone",
          "Speaker",
          "TV",
          "AVR",
          "STB",
          "AudioDongle",
          "GameConsole",
          "CastVideo",
          "CastAudio",
          "Automobile",
          "Smartwatch",
          "Chromebook"
        ]
        default: "Speaker"
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