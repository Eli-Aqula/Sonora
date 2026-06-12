// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsGeniusDescription =>
      'Genius API is used to automatically fetch metadata (title, artist, album, year, cover art, lyrics).';

  @override
  String get settingsGeniusTokenLabel => 'Genius API token';

  @override
  String get settingsTokenHint => 'Paste your client token…';

  @override
  String get settingsEnterTokenToTest => 'Enter a token to test it';

  @override
  String settingsTokenWorks(int count) {
    return 'Token works ($count hits)';
  }

  @override
  String settingsGenericError(String error) {
    return 'Error: $error';
  }

  @override
  String get settingsTokenRemoved => 'Genius token removed';

  @override
  String get settingsTokenSaved => 'Genius token saved';

  @override
  String get settingsAutoEnrichLabel => 'Auto-update on import';

  @override
  String get settingsSetTokenFirst => 'Set and save a token first';

  @override
  String get settingsAutoEnrichDescription =>
      'Automatically update metadata when importing a folder';

  @override
  String get settingsTokenStatusSaved => 'Token saved';

  @override
  String get settingsTokenStatusNotSet => 'Token not set';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsLyricsSectionTitle => 'Synchronized lyrics';

  @override
  String get settingsLyricsDescription =>
      'Lyrics are fetched from LRCLib — an open database of professionally synchronized lyrics. No setup required: press \"Sync\" on a track and the app will look up the LRC by its tags automatically. Internet access is only needed while searching.';

  @override
  String get settingsGetTokenInstructions =>
      'Get a token at genius.com/api-clients → \"Generate Access Token\".';

  @override
  String get settingsTesting => 'Testing…';

  @override
  String get settingsTest => 'Test';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonOk => 'OK';

  @override
  String get commonName => 'Name';

  @override
  String commonError(String error) {
    return 'Error: $error';
  }

  @override
  String get navSearch => 'Search';

  @override
  String get navHome => 'Home';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get sidebarPlaylists => 'Playlists';

  @override
  String get sidebarCreatePlaylist => 'Create playlist';

  @override
  String get sidebarPlaylistsEmpty => 'Playlists will appear here';

  @override
  String get sidebarNewPlaylistTitle => 'New playlist';

  @override
  String get sidebarChangeCover => 'Change cover';

  @override
  String get sidebarSetCover => 'Set cover';

  @override
  String get sidebarRemoveCover => 'Remove cover';

  @override
  String get sidebarCoverSetFailedTitle => 'Couldn\'t set cover';

  @override
  String get sidebarDeletePlaylistTitle => 'Delete playlist?';

  @override
  String sidebarDeletePlaylistConfirm(String name) {
    return '\"$name\" will be deleted permanently.';
  }

  @override
  String get commonSeeAll => 'All →';

  @override
  String homeTracksCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String homeAlbumsCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String homeArtistsCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String get homeRescan => 'Rescan';

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homeAllTracks => 'All tracks';

  @override
  String get homeShuffleTitle => 'Shuffle';

  @override
  String get homeShuffleSubtitle => 'Random order';

  @override
  String get nowPlayingLabel => 'Now playing';

  @override
  String get homeAlbumsTitle => 'Albums';

  @override
  String get homeNoAlbums => 'No albums yet';

  @override
  String get homeArtistsTitle => 'Artists';

  @override
  String get homeNoArtists => 'No artists yet';

  @override
  String get homeCreatePlaylistHint => 'Create a playlist from the sidebar';

  @override
  String get homeRecentlyAdded => 'Recently added';

  @override
  String get homeEmptyTitle => 'Add a music folder';

  @override
  String get homeEmptyDescription =>
      'Sonora will scan the selected folder and fetch metadata.\nSupported formats: MP3, FLAC, M4A, OGG, OPUS, WAV.';

  @override
  String get homeChooseFolder => 'Choose folder';

  @override
  String get commonAll => 'All';

  @override
  String get mobileAudioPermissionMessage =>
      'Sonora needs access to audio files';

  @override
  String mobileFilePickError(String error) {
    return 'Error picking files: $error';
  }

  @override
  String get mobileShuffle => 'Shuffle';

  @override
  String get mobileEmptyTitle => 'Add music';

  @override
  String get mobileEmptyDescription =>
      'Sonora plays MP3, FLAC, M4A, OGG, OPUS, WAV.';

  @override
  String get mobileChooseFiles => 'Choose files';

  @override
  String get commonClose => 'Close';

  @override
  String get playerNothingPlaying => 'Nothing playing';

  @override
  String get playerLyricsTooltip => 'Lyrics';

  @override
  String get playerActionsTooltip => 'Actions';

  @override
  String get playerPreviousTooltip => 'Previous';

  @override
  String get playerNextTooltip => 'Next';

  @override
  String get playerRepeatOff => 'Repeat: off';

  @override
  String get playerRepeatAll => 'Repeat: all';

  @override
  String get playerRepeatOne => 'Repeat: one';

  @override
  String get playerRemoveFavorite => 'Remove from favorites';

  @override
  String get playerAddFavorite => 'Add to favorites';

  @override
  String get playerCollapse => 'Collapse';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsNotFound => 'Lyrics not found';

  @override
  String get lyricsResync => 'Resync';

  @override
  String get lyricsSync => 'Sync';

  @override
  String get playerMuteTooltip => 'Mute';

  @override
  String get playerUnmuteTooltip => 'Unmute';

  @override
  String get trackAddToPlaylist => 'Add to playlist';

  @override
  String get trackEditTags => 'Edit tags';

  @override
  String get trackFindOnGenius => 'Find on Genius';

  @override
  String get trackDeleteFromDevice => 'Delete from device';

  @override
  String get trackNotInLibrary => 'Track is not yet saved in the library';

  @override
  String get trackCreatePlaylistFirst => 'Create a playlist first';

  @override
  String trackAddedToPlaylist(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String get trackDeleteTitle => 'Delete track?';

  @override
  String trackDeleteConfirm(String title) {
    return 'The file \"$title\" will be permanently deleted from the device.';
  }

  @override
  String trackDeleted(String title) {
    return '\"$title\" deleted';
  }

  @override
  String trackTagsUpdated(String title) {
    return 'Tags for \"$title\" updated';
  }

  @override
  String trackTagsUpdatedFrom(String title) {
    return 'Tags updated from \"$title\"';
  }

  @override
  String trackTagsWriteFailed(String error) {
    return 'Failed to write tags: $error';
  }

  @override
  String geniusError(String error) {
    return 'Genius: $error';
  }

  @override
  String get geniusSearchingEllipsis => 'Searching Genius…';

  @override
  String geniusNoResultsFor(String title) {
    return 'No results found for \"$title\"';
  }

  @override
  String get geniusChangeQuery => 'Change query';

  @override
  String get geniusUnknownError => 'Unknown error';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonApply => 'Apply';

  @override
  String get geniusSearchingShort => 'Searching…';

  @override
  String geniusMatchesFound(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString matches found',
      one: '1 match found',
    );
    return '$_temp0';
  }

  @override
  String get geniusNothingFound => 'Nothing found';

  @override
  String get geniusErrorLabel => 'Error';

  @override
  String get geniusSingle => 'Single';

  @override
  String get geniusSearchButton => 'Search';

  @override
  String get geniusQueryHint => 'e.g.: Artist Song Title';

  @override
  String get geniusArtistSearchingEllipsis => 'Searching artists on Genius…';

  @override
  String geniusArtistsFound(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString artists found',
      one: '1 artist found',
    );
    return '$_temp0';
  }

  @override
  String get geniusFindArtist => 'Find artist on Genius';

  @override
  String get geniusArtistQueryHint => 'e.g.: Sugarcult';

  @override
  String get lyricsSyncingEllipsis => 'Syncing...';

  @override
  String get lyricsOffsetLabel => 'Offset:';

  @override
  String lyricsOffsetValue(String value) {
    return '${value}s';
  }

  @override
  String lyricsEarlierBy(String seconds) {
    return 'Lyrics ${seconds}s earlier';
  }

  @override
  String lyricsLaterBy(String seconds) {
    return 'Lyrics ${seconds}s later';
  }

  @override
  String get tagEditorChooseCoverImageDialog => 'Choose a cover image';

  @override
  String get tagEditorTitle => 'Edit tags';

  @override
  String get tagEditorPlayingWarning =>
      'This track is currently playing. Writing may be blocked — pause it first.';

  @override
  String get tagEditorTitleField => 'Title';

  @override
  String get tagEditorArtist => 'Artist';

  @override
  String get tagEditorAlbum => 'Album';

  @override
  String get tagEditorAlbumArtist => 'Album artist';

  @override
  String get tagEditorYear => 'Year';

  @override
  String get tagEditorTrackNumber => 'Track #';

  @override
  String get tagEditorDiscNumber => 'Disc #';

  @override
  String get tagEditorGenre => 'Genre';

  @override
  String get tagEditorSaving => 'Saving…';

  @override
  String get tagEditorChooseCover => 'Choose cover';

  @override
  String get tagEditorRevertCover => 'Revert to original';

  @override
  String get commonBack => 'Back';

  @override
  String get playlistEmptyMessage =>
      'This playlist is empty. Add tracks from the library\'s context menu.';

  @override
  String get playlistLabel => 'PLAYLIST';

  @override
  String get playlistListen => 'Listen';

  @override
  String get playlistShuffle => 'Shuffle';

  @override
  String get playlistCoverTooltip => 'Cover';

  @override
  String get libraryAddFolder => 'Add folder';

  @override
  String get libraryRemoveFolderTitle => 'Remove folder?';

  @override
  String libraryRemoveFolderConfirm(String path) {
    return 'The folder \"$path\" will be removed from the watched list, and its tracks will be removed from the library.';
  }

  @override
  String get libraryTabTracks => 'Tracks';

  @override
  String get libraryTabAlbums => 'Albums';

  @override
  String get libraryTabArtists => 'Artists';

  @override
  String get libraryTabFolders => 'Folders';

  @override
  String get libraryNoFolders => 'No folders added yet';

  @override
  String libraryArtistAlbumsAndTracks(String albums, String tracks) {
    return '$albums • $tracks';
  }

  @override
  String get favoritesNoTracks => 'No favorite tracks yet';

  @override
  String get favoritesNoAlbums => 'No favorite albums yet';

  @override
  String get favoritesNoArtists => 'No favorite artists yet';

  @override
  String get artistLabel => 'ARTIST';

  @override
  String artistDataFetched(String name) {
    return 'Fetched data for \"$name\"';
  }

  @override
  String get albumLabel => 'ALBUM';

  @override
  String get albumNoTracks => 'No tracks';

  @override
  String get searchHint => 'Track, artist or album…';

  @override
  String get searchHistoryEmpty => 'Your recent searches will appear here';

  @override
  String get searchHistoryTitle => 'History';

  @override
  String searchResultsFound(int count) {
    return 'Found: $count';
  }

  @override
  String get trackPlay => 'Play';

  @override
  String get trackAddToQueue => 'Add to queue';

  @override
  String get trackAddToPlaylistEllipsis => 'Add to playlist…';

  @override
  String get trackEditTagsEllipsis => 'Edit tags…';

  @override
  String trackAddedToQueue(String title) {
    return '\"$title\" added to queue';
  }

  @override
  String trackAddedToFavorites(String title) {
    return '\"$title\" added to favorites';
  }

  @override
  String trackRemovedFromFavorites(String title) {
    return '\"$title\" removed from favorites';
  }

  @override
  String get trackListEmpty => 'Nothing here yet';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }
}
