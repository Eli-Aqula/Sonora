import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsGeniusDescription.
  ///
  /// In en, this message translates to:
  /// **'Genius API is used to automatically fetch metadata (title, artist, album, year, cover art, lyrics).'**
  String get settingsGeniusDescription;

  /// No description provided for @settingsGeniusTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Genius API token'**
  String get settingsGeniusTokenLabel;

  /// No description provided for @settingsTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your client token…'**
  String get settingsTokenHint;

  /// No description provided for @settingsEnterTokenToTest.
  ///
  /// In en, this message translates to:
  /// **'Enter a token to test it'**
  String get settingsEnterTokenToTest;

  /// No description provided for @settingsTokenWorks.
  ///
  /// In en, this message translates to:
  /// **'Token works ({count} hits)'**
  String settingsTokenWorks(int count);

  /// No description provided for @settingsGenericError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String settingsGenericError(String error);

  /// No description provided for @settingsTokenRemoved.
  ///
  /// In en, this message translates to:
  /// **'Genius token removed'**
  String get settingsTokenRemoved;

  /// No description provided for @settingsTokenSaved.
  ///
  /// In en, this message translates to:
  /// **'Genius token saved'**
  String get settingsTokenSaved;

  /// No description provided for @settingsAutoEnrichLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-update on import'**
  String get settingsAutoEnrichLabel;

  /// No description provided for @settingsSetTokenFirst.
  ///
  /// In en, this message translates to:
  /// **'Set and save a token first'**
  String get settingsSetTokenFirst;

  /// No description provided for @settingsAutoEnrichDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically update metadata when importing a folder'**
  String get settingsAutoEnrichDescription;

  /// No description provided for @settingsTokenStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Token saved'**
  String get settingsTokenStatusSaved;

  /// No description provided for @settingsTokenStatusNotSet.
  ///
  /// In en, this message translates to:
  /// **'Token not set'**
  String get settingsTokenStatusNotSet;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsLyricsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Synchronized lyrics'**
  String get settingsLyricsSectionTitle;

  /// No description provided for @settingsLyricsDescription.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are fetched from LRCLib — an open database of professionally synchronized lyrics. No setup required: press \"Sync\" on a track and the app will look up the LRC by its tags automatically. Internet access is only needed while searching.'**
  String get settingsLyricsDescription;

  /// No description provided for @settingsGetTokenInstructions.
  ///
  /// In en, this message translates to:
  /// **'Get a token at genius.com/api-clients → \"Generate Access Token\".'**
  String get settingsGetTokenInstructions;

  /// No description provided for @settingsTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get settingsTesting;

  /// No description provided for @settingsTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get settingsTest;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonError(String error);

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @sidebarPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get sidebarPlaylists;

  /// No description provided for @sidebarCreatePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create playlist'**
  String get sidebarCreatePlaylist;

  /// No description provided for @sidebarPlaylistsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Playlists will appear here'**
  String get sidebarPlaylistsEmpty;

  /// No description provided for @sidebarNewPlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get sidebarNewPlaylistTitle;

  /// No description provided for @sidebarChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Change cover'**
  String get sidebarChangeCover;

  /// No description provided for @sidebarSetCover.
  ///
  /// In en, this message translates to:
  /// **'Set cover'**
  String get sidebarSetCover;

  /// No description provided for @sidebarRemoveCover.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get sidebarRemoveCover;

  /// No description provided for @sidebarCoverSetFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set cover'**
  String get sidebarCoverSetFailedTitle;

  /// No description provided for @sidebarDeletePlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist?'**
  String get sidebarDeletePlaylistTitle;

  /// No description provided for @sidebarDeletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be deleted permanently.'**
  String sidebarDeletePlaylistConfirm(String name);

  /// No description provided for @commonSeeAll.
  ///
  /// In en, this message translates to:
  /// **'All →'**
  String get commonSeeAll;

  /// No description provided for @homeTracksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String homeTracksCount(num count);

  /// No description provided for @homeAlbumsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album} other{{count} albums}}'**
  String homeAlbumsCount(num count);

  /// No description provided for @homeArtistsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 artist} other{{count} artists}}'**
  String homeArtistsCount(num count);

  /// No description provided for @homeRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get homeRescan;

  /// No description provided for @homeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickActions;

  /// No description provided for @homeAllTracks.
  ///
  /// In en, this message translates to:
  /// **'All tracks'**
  String get homeAllTracks;

  /// No description provided for @homeShuffleTitle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get homeShuffleTitle;

  /// No description provided for @homeShuffleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Random order'**
  String get homeShuffleSubtitle;

  /// No description provided for @nowPlayingLabel.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlayingLabel;

  /// No description provided for @homeAlbumsTitle.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get homeAlbumsTitle;

  /// No description provided for @homeNoAlbums.
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get homeNoAlbums;

  /// No description provided for @homeArtistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get homeArtistsTitle;

  /// No description provided for @homeNoArtists.
  ///
  /// In en, this message translates to:
  /// **'No artists yet'**
  String get homeNoArtists;

  /// No description provided for @homeCreatePlaylistHint.
  ///
  /// In en, this message translates to:
  /// **'Create a playlist from the sidebar'**
  String get homeCreatePlaylistHint;

  /// No description provided for @homeRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get homeRecentlyAdded;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Sonora will scan the selected folder and fetch metadata.\nSupported formats: MP3, FLAC, M4A, OGG, OPUS, WAV.'**
  String get homeEmptyDescription;

  /// No description provided for @homeChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get homeChooseFolder;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @mobileAudioPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Sonora needs access to audio files'**
  String get mobileAudioPermissionMessage;

  /// No description provided for @mobileFilePickError.
  ///
  /// In en, this message translates to:
  /// **'Error picking files: {error}'**
  String mobileFilePickError(String error);

  /// No description provided for @mobileShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get mobileShuffle;

  /// No description provided for @mobileEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add music'**
  String get mobileEmptyTitle;

  /// No description provided for @mobileEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Sonora plays MP3, FLAC, M4A, OGG, OPUS, WAV.'**
  String get mobileEmptyDescription;

  /// No description provided for @mobileChooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get mobileChooseFiles;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @playerNothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get playerNothingPlaying;

  /// No description provided for @playerLyricsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get playerLyricsTooltip;

  /// No description provided for @playerActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get playerActionsTooltip;

  /// No description provided for @playerPreviousTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playerPreviousTooltip;

  /// No description provided for @playerNextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playerNextTooltip;

  /// No description provided for @playerRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat: off'**
  String get playerRepeatOff;

  /// No description provided for @playerRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat: all'**
  String get playerRepeatAll;

  /// No description provided for @playerRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat: one'**
  String get playerRepeatOne;

  /// No description provided for @playerRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get playerRemoveFavorite;

  /// No description provided for @playerAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get playerAddFavorite;

  /// No description provided for @playerCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get playerCollapse;

  /// No description provided for @lyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsTitle;

  /// No description provided for @lyricsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Lyrics not found'**
  String get lyricsNotFound;

  /// No description provided for @lyricsResync.
  ///
  /// In en, this message translates to:
  /// **'Resync'**
  String get lyricsResync;

  /// No description provided for @lyricsSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get lyricsSync;

  /// No description provided for @playerMuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMuteTooltip;

  /// No description provided for @playerUnmuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmuteTooltip;

  /// No description provided for @trackAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get trackAddToPlaylist;

  /// No description provided for @trackEditTags.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get trackEditTags;

  /// No description provided for @trackFindOnGenius.
  ///
  /// In en, this message translates to:
  /// **'Find on Genius'**
  String get trackFindOnGenius;

  /// No description provided for @trackDeleteFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Delete from device'**
  String get trackDeleteFromDevice;

  /// No description provided for @trackNotInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Track is not yet saved in the library'**
  String get trackNotInLibrary;

  /// No description provided for @trackCreatePlaylistFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a playlist first'**
  String get trackCreatePlaylistFirst;

  /// No description provided for @trackAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to \"{name}\"'**
  String trackAddedToPlaylist(String name);

  /// No description provided for @trackDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete track?'**
  String get trackDeleteTitle;

  /// No description provided for @trackDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'The file \"{title}\" will be permanently deleted from the device.'**
  String trackDeleteConfirm(String title);

  /// No description provided for @trackDeleted.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" deleted'**
  String trackDeleted(String title);

  /// No description provided for @trackTagsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Tags for \"{title}\" updated'**
  String trackTagsUpdated(String title);

  /// No description provided for @trackTagsUpdatedFrom.
  ///
  /// In en, this message translates to:
  /// **'Tags updated from \"{title}\"'**
  String trackTagsUpdatedFrom(String title);

  /// No description provided for @trackTagsWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to write tags: {error}'**
  String trackTagsWriteFailed(String error);

  /// No description provided for @geniusError.
  ///
  /// In en, this message translates to:
  /// **'Genius: {error}'**
  String geniusError(String error);

  /// No description provided for @geniusSearchingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Searching Genius…'**
  String get geniusSearchingEllipsis;

  /// No description provided for @geniusNoResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{title}\"'**
  String geniusNoResultsFor(String title);

  /// No description provided for @geniusChangeQuery.
  ///
  /// In en, this message translates to:
  /// **'Change query'**
  String get geniusChangeQuery;

  /// No description provided for @geniusUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get geniusUnknownError;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @geniusSearchingShort.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get geniusSearchingShort;

  /// No description provided for @geniusMatchesFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match found} other{{count} matches found}}'**
  String geniusMatchesFound(num count);

  /// No description provided for @geniusNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get geniusNothingFound;

  /// No description provided for @geniusErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get geniusErrorLabel;

  /// No description provided for @geniusSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get geniusSingle;

  /// No description provided for @geniusSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get geniusSearchButton;

  /// No description provided for @geniusQueryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g.: Artist Song Title'**
  String get geniusQueryHint;

  /// No description provided for @geniusArtistSearchingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Searching artists on Genius…'**
  String get geniusArtistSearchingEllipsis;

  /// No description provided for @geniusArtistsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 artist found} other{{count} artists found}}'**
  String geniusArtistsFound(num count);

  /// No description provided for @geniusFindArtist.
  ///
  /// In en, this message translates to:
  /// **'Find artist on Genius'**
  String get geniusFindArtist;

  /// No description provided for @geniusArtistQueryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g.: Sugarcult'**
  String get geniusArtistQueryHint;

  /// No description provided for @lyricsSyncingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get lyricsSyncingEllipsis;

  /// No description provided for @lyricsOffsetLabel.
  ///
  /// In en, this message translates to:
  /// **'Offset:'**
  String get lyricsOffsetLabel;

  /// No description provided for @lyricsOffsetValue.
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String lyricsOffsetValue(String value);

  /// No description provided for @lyricsEarlierBy.
  ///
  /// In en, this message translates to:
  /// **'Lyrics {seconds}s earlier'**
  String lyricsEarlierBy(String seconds);

  /// No description provided for @lyricsLaterBy.
  ///
  /// In en, this message translates to:
  /// **'Lyrics {seconds}s later'**
  String lyricsLaterBy(String seconds);

  /// No description provided for @tagEditorChooseCoverImageDialog.
  ///
  /// In en, this message translates to:
  /// **'Choose a cover image'**
  String get tagEditorChooseCoverImageDialog;

  /// No description provided for @tagEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get tagEditorTitle;

  /// No description provided for @tagEditorPlayingWarning.
  ///
  /// In en, this message translates to:
  /// **'This track is currently playing. Writing may be blocked — pause it first.'**
  String get tagEditorPlayingWarning;

  /// No description provided for @tagEditorTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get tagEditorTitleField;

  /// No description provided for @tagEditorArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get tagEditorArtist;

  /// No description provided for @tagEditorAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get tagEditorAlbum;

  /// No description provided for @tagEditorAlbumArtist.
  ///
  /// In en, this message translates to:
  /// **'Album artist'**
  String get tagEditorAlbumArtist;

  /// No description provided for @tagEditorYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get tagEditorYear;

  /// No description provided for @tagEditorTrackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track #'**
  String get tagEditorTrackNumber;

  /// No description provided for @tagEditorDiscNumber.
  ///
  /// In en, this message translates to:
  /// **'Disc #'**
  String get tagEditorDiscNumber;

  /// No description provided for @tagEditorGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get tagEditorGenre;

  /// No description provided for @tagEditorSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get tagEditorSaving;

  /// No description provided for @tagEditorChooseCover.
  ///
  /// In en, this message translates to:
  /// **'Choose cover'**
  String get tagEditorChooseCover;

  /// No description provided for @tagEditorRevertCover.
  ///
  /// In en, this message translates to:
  /// **'Revert to original'**
  String get tagEditorRevertCover;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @playlistEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty. Add tracks from the library\'s context menu.'**
  String get playlistEmptyMessage;

  /// No description provided for @playlistLabel.
  ///
  /// In en, this message translates to:
  /// **'PLAYLIST'**
  String get playlistLabel;

  /// No description provided for @playlistListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get playlistListen;

  /// No description provided for @playlistShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playlistShuffle;

  /// No description provided for @playlistCoverTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get playlistCoverTooltip;

  /// No description provided for @libraryAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get libraryAddFolder;

  /// No description provided for @libraryRemoveFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove folder?'**
  String get libraryRemoveFolderTitle;

  /// No description provided for @libraryRemoveFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'The folder \"{path}\" will be removed from the watched list, and its tracks will be removed from the library.'**
  String libraryRemoveFolderConfirm(String path);

  /// No description provided for @libraryTabTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get libraryTabTracks;

  /// No description provided for @libraryTabAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get libraryTabAlbums;

  /// No description provided for @libraryTabArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryTabArtists;

  /// No description provided for @libraryTabFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libraryTabFolders;

  /// No description provided for @libraryNoFolders.
  ///
  /// In en, this message translates to:
  /// **'No folders added yet'**
  String get libraryNoFolders;

  /// No description provided for @libraryArtistAlbumsAndTracks.
  ///
  /// In en, this message translates to:
  /// **'{albums} • {tracks}'**
  String libraryArtistAlbumsAndTracks(String albums, String tracks);

  /// No description provided for @favoritesNoTracks.
  ///
  /// In en, this message translates to:
  /// **'No favorite tracks yet'**
  String get favoritesNoTracks;

  /// No description provided for @favoritesNoAlbums.
  ///
  /// In en, this message translates to:
  /// **'No favorite albums yet'**
  String get favoritesNoAlbums;

  /// No description provided for @favoritesNoArtists.
  ///
  /// In en, this message translates to:
  /// **'No favorite artists yet'**
  String get favoritesNoArtists;

  /// No description provided for @artistLabel.
  ///
  /// In en, this message translates to:
  /// **'ARTIST'**
  String get artistLabel;

  /// No description provided for @artistDataFetched.
  ///
  /// In en, this message translates to:
  /// **'Fetched data for \"{name}\"'**
  String artistDataFetched(String name);

  /// No description provided for @albumLabel.
  ///
  /// In en, this message translates to:
  /// **'ALBUM'**
  String get albumLabel;

  /// No description provided for @albumNoTracks.
  ///
  /// In en, this message translates to:
  /// **'No tracks'**
  String get albumNoTracks;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Track, artist or album…'**
  String get searchHint;

  /// No description provided for @searchHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your recent searches will appear here'**
  String get searchHistoryEmpty;

  /// No description provided for @searchHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get searchHistoryTitle;

  /// No description provided for @searchResultsFound.
  ///
  /// In en, this message translates to:
  /// **'Found: {count}'**
  String searchResultsFound(int count);

  /// No description provided for @trackPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get trackPlay;

  /// No description provided for @trackAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get trackAddToQueue;

  /// No description provided for @trackAddToPlaylistEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist…'**
  String get trackAddToPlaylistEllipsis;

  /// No description provided for @trackEditTagsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Edit tags…'**
  String get trackEditTagsEllipsis;

  /// No description provided for @trackAddedToQueue.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" added to queue'**
  String trackAddedToQueue(String title);

  /// No description provided for @trackAddedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" added to favorites'**
  String trackAddedToFavorites(String title);

  /// No description provided for @trackRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" removed from favorites'**
  String trackRemovedFromFavorites(String title);

  /// No description provided for @trackListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get trackListEmpty;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutes(int minutes);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
