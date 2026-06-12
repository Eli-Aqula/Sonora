import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/album.dart';
import '../data/models/artist.dart';
import '../data/models/playlist.dart';

sealed class PanelEntry {
  const PanelEntry();
}

class PlaylistPanel extends PanelEntry {
  final Playlist playlist;
  const PlaylistPanel(this.playlist);

  @override
  bool operator ==(Object other) =>
      other is PlaylistPanel && other.playlist.id == playlist.id;
  @override
  int get hashCode => playlist.id?.hashCode ?? playlist.hashCode;
}

class AlbumPanel extends PanelEntry {
  final Album album;
  const AlbumPanel(this.album);

  @override
  bool operator ==(Object other) =>
      other is AlbumPanel &&
      other.album.name == album.name &&
      other.album.artist == album.artist;
  @override
  int get hashCode => Object.hash(album.name, album.artist);
}

class ArtistPanel extends PanelEntry {
  final Artist artist;
  const ArtistPanel(this.artist);

  @override
  bool operator ==(Object other) =>
      other is ArtistPanel && other.artist.name == artist.name;
  @override
  int get hashCode => artist.name.hashCode;
}

class PanelNotifier extends Notifier<List<PanelEntry>> {
  @override
  List<PanelEntry> build() => const [];

  void openPlaylist(Playlist p) => state = [...state, PlaylistPanel(p)];
  void openAlbum(Album a) => state = [...state, AlbumPanel(a)];
  void openArtist(Artist a) => state = [...state, ArtistPanel(a)];

  void pop() {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const [];
  }
}

final panelProvider =
    NotifierProvider<PanelNotifier, List<PanelEntry>>(PanelNotifier.new);
