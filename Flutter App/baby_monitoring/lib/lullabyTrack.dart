
class LullabyTrack {
  String trackID;
  String trackURI;
  String trackName;
  String artistName;
  String albumName;

  LullabyTrack(String trackID, String trackURI, String trackName, String artistName, String albumName)
  {
    this.trackID = trackID;
    this.trackURI = trackURI;
    this.trackName = trackName;
    this.artistName = artistName;
    this.albumName = albumName;
  }

  LullabyTrack.emptyConstructor()
  {
    this.trackID = null;
    this.trackURI = null;
    this.trackName = null;
    this.artistName = null;
    this.albumName = null;
  }

  //overridden '==' operator to allow for the comparison between two LullabyTrack objects (based on the *member variables* themselves)
  /*(e.g. this method is used when selecting the previously-selected lullaby track on loading the 'Select Lullaby' Page)*/
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LullabyTrack &&
          trackID == other.trackID &&
          trackURI == other.trackURI &&
          trackName == other.trackName &&
          artistName == other.artistName &&
          albumName == other.albumName;

  @override
  int get hashCode =>
      trackID.hashCode ^
      trackURI.hashCode ^
      trackName.hashCode ^
      artistName.hashCode ^
      albumName.hashCode;
}