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
      default_volume:
        description: "Default playback volume for this device (0-100)"
        type: "number"
        default: 30
    }
  },
  SpotifyPlaylist: {
    title: "Spotify playlist Device"
    description: "Spotify Playlist Device configuration"
    type: "object"
    extensions: ["xLink", "xOnLabel", "xOffLabel"]
    properties: {
      spotify_id:
        description: "The Spotify ID of your playlist"
        type: "string"
        required: true
      spotify_uri:
        description: "The Spotify context URI of your playlist"
        type: "string"
        required: true
      spotify_type:
        description: "The Spotify Type of your playlist"
        enum: [
          "playlist"
        ]
        default: "playlist"
      shuffle:
        description: "Shuffle songs during playback"
        type: "boolean"
        default: false
    }
  }
}