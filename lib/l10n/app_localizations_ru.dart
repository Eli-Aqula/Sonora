// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguageLabel => 'Язык';

  @override
  String get settingsGeniusDescription =>
      'Genius API используется для автоматической подгрузки метаданных (название, исполнитель, альбом, год, обложка, текст).';

  @override
  String get settingsGeniusTokenLabel => 'Токен Genius API';

  @override
  String get settingsTokenHint => 'Вставьте клиентский токен…';

  @override
  String get settingsEnterTokenToTest => 'Введите токен, чтобы проверить';

  @override
  String settingsTokenWorks(int count) {
    return 'Токен работает (хитов: $count)';
  }

  @override
  String settingsGenericError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get settingsTokenRemoved => 'Токен Genius удалён';

  @override
  String get settingsTokenSaved => 'Токен Genius сохранён';

  @override
  String get settingsAutoEnrichLabel => 'Авто-обновление при импорте';

  @override
  String get settingsSetTokenFirst => 'Сначала задайте и сохраните токен';

  @override
  String get settingsAutoEnrichDescription =>
      'Авто-обновлять метаданные при импорте папки';

  @override
  String get settingsTokenStatusSaved => 'Токен сохранён';

  @override
  String get settingsTokenStatusNotSet => 'Токен не задан';

  @override
  String get settingsCancel => 'Отмена';

  @override
  String get settingsSave => 'Сохранить';

  @override
  String get settingsLyricsSectionTitle => 'Синхронизированный текст';

  @override
  String get settingsLyricsDescription =>
      'Текст подтягивается с LRCLib — открытой базы профессионально синхронизированных lyrics. Никакой установки не требуется: нажмите «Синхронизировать» на треке, и приложение найдёт LRC по тегам автоматически. Доступ в интернет нужен только на момент поиска.';

  @override
  String get settingsGetTokenInstructions =>
      'Получите токен на genius.com/api-clients → «Generate Access Token».';

  @override
  String get settingsTesting => 'Проверка…';

  @override
  String get settingsTest => 'Проверить';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonCreate => 'Создать';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonRename => 'Переименовать';

  @override
  String get commonOk => 'Ок';

  @override
  String get commonName => 'Название';

  @override
  String commonError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get navSearch => 'Поиск';

  @override
  String get navHome => 'Главная';

  @override
  String get navFavorites => 'Любимое';

  @override
  String get navLibrary => 'Библиотека';

  @override
  String get navSettings => 'Настройки';

  @override
  String get sidebarPlaylists => 'Плейлисты';

  @override
  String get sidebarCreatePlaylist => 'Создать плейлист';

  @override
  String get sidebarPlaylistsEmpty => 'Здесь будут плейлисты';

  @override
  String get sidebarNewPlaylistTitle => 'Новый плейлист';

  @override
  String get sidebarChangeCover => 'Изменить обложку';

  @override
  String get sidebarSetCover => 'Установить обложку';

  @override
  String get sidebarRemoveCover => 'Удалить обложку';

  @override
  String get sidebarCoverSetFailedTitle => 'Не удалось установить обложку';

  @override
  String get sidebarDeletePlaylistTitle => 'Удалить плейлист?';

  @override
  String sidebarDeletePlaylistConfirm(String name) {
    return '«$name» будет удалён без возможности восстановления.';
  }

  @override
  String get commonSeeAll => 'Все →';

  @override
  String homeTracksCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString трека',
      many: '$countString треков',
      few: '$countString трека',
      one: '$countString трек',
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
      other: '$countString альбома',
      many: '$countString альбомов',
      few: '$countString альбома',
      one: '$countString альбом',
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
      other: '$countString артиста',
      many: '$countString артистов',
      few: '$countString артиста',
      one: '$countString артист',
    );
    return '$_temp0';
  }

  @override
  String get homeRescan => 'Пересканировать';

  @override
  String get homeQuickActions => 'Быстрое действие';

  @override
  String get homeAllTracks => 'Все треки';

  @override
  String get homeShuffleTitle => 'В случайном порядке';

  @override
  String get homeShuffleSubtitle => 'Перемешать';

  @override
  String get nowPlayingLabel => 'Сейчас играет';

  @override
  String get homeAlbumsTitle => 'Альбомы';

  @override
  String get homeNoAlbums => 'Пока нет альбомов';

  @override
  String get homeArtistsTitle => 'Артисты';

  @override
  String get homeNoArtists => 'Пока нет артистов';

  @override
  String get homeCreatePlaylistHint => 'Создайте плейлист в боковой панели';

  @override
  String get homeRecentlyAdded => 'Недавно добавленные';

  @override
  String get homeEmptyTitle => 'Добавьте папку с музыкой';

  @override
  String get homeEmptyDescription =>
      'Sonora просканирует выбранную папку и подтянет метаданные.\nПоддерживаются MP3, FLAC, M4A, OGG, OPUS, WAV.';

  @override
  String get homeChooseFolder => 'Выбрать папку';

  @override
  String get commonAll => 'Все';

  @override
  String get mobileAudioPermissionMessage =>
      'Sonora нужен доступ к аудиофайлам';

  @override
  String mobileFilePickError(String error) {
    return 'Ошибка выбора файлов: $error';
  }

  @override
  String get mobileShuffle => 'Случайный';

  @override
  String get mobileEmptyTitle => 'Добавьте музыку';

  @override
  String get mobileEmptyDescription =>
      'Sonora проигрывает MP3, FLAC, M4A, OGG, OPUS, WAV.';

  @override
  String get mobileChooseFiles => 'Выбрать файлы';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get playerNothingPlaying => 'Ничего не играет';

  @override
  String get playerLyricsTooltip => 'Текст';

  @override
  String get playerActionsTooltip => 'Действия';

  @override
  String get playerPreviousTooltip => 'Предыдущий';

  @override
  String get playerNextTooltip => 'Следующий';

  @override
  String get playerRepeatOff => 'Повтор: выкл';

  @override
  String get playerRepeatAll => 'Повтор: всё';

  @override
  String get playerRepeatOne => 'Повтор: трек';

  @override
  String get playerRemoveFavorite => 'Убрать из любимого';

  @override
  String get playerAddFavorite => 'В любимое';

  @override
  String get playerCollapse => 'Свернуть';

  @override
  String get lyricsTitle => 'Текст песни';

  @override
  String get lyricsNotFound => 'Текст не найден';

  @override
  String get lyricsResync => 'Пересинхронизировать';

  @override
  String get lyricsSync => 'Синхронизировать';

  @override
  String get playerMuteTooltip => 'Выключить звук';

  @override
  String get playerUnmuteTooltip => 'Включить звук';

  @override
  String get trackAddToPlaylist => 'Добавить в плейлист';

  @override
  String get trackEditTags => 'Редактировать теги';

  @override
  String get trackFindOnGenius => 'Найти на Genius';

  @override
  String get trackDeleteFromDevice => 'Удалить с устройства';

  @override
  String get trackNotInLibrary => 'Трек ещё не сохранён в библиотеке';

  @override
  String get trackCreatePlaylistFirst => 'Сначала создайте плейлист';

  @override
  String trackAddedToPlaylist(String name) {
    return 'Добавлено в «$name»';
  }

  @override
  String get trackDeleteTitle => 'Удалить трек?';

  @override
  String trackDeleteConfirm(String title) {
    return 'Файл «$title» будет удалён с устройства без возможности восстановления.';
  }

  @override
  String trackDeleted(String title) {
    return '«$title» удалён';
  }

  @override
  String trackTagsUpdated(String title) {
    return 'Теги «$title» обновлены';
  }

  @override
  String trackTagsUpdatedFrom(String title) {
    return 'Теги обновлены по «$title»';
  }

  @override
  String trackTagsWriteFailed(String error) {
    return 'Не удалось записать теги: $error';
  }

  @override
  String geniusError(String error) {
    return 'Genius: $error';
  }

  @override
  String get geniusSearchingEllipsis => 'Идёт поиск в Genius…';

  @override
  String geniusNoResultsFor(String title) {
    return 'Ничего не найдено для «$title»';
  }

  @override
  String get geniusChangeQuery => 'Изменить запрос';

  @override
  String get geniusUnknownError => 'Неизвестная ошибка';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonApply => 'Применить';

  @override
  String get geniusSearchingShort => 'Поиск…';

  @override
  String geniusMatchesFound(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Найдено $countString совпадения',
      many: 'Найдено $countString совпадений',
      few: 'Найдено $countString совпадения',
      one: 'Найдено $countString совпадение',
    );
    return '$_temp0';
  }

  @override
  String get geniusNothingFound => 'Ничего не найдено';

  @override
  String get geniusErrorLabel => 'Ошибка';

  @override
  String get geniusSingle => 'Сингл';

  @override
  String get geniusSearchButton => 'Искать';

  @override
  String get geniusQueryHint => 'Например: Платина Один дома';

  @override
  String get geniusArtistSearchingEllipsis => 'Идёт поиск артистов в Genius…';

  @override
  String geniusArtistsFound(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Найдено $countString артиста',
      many: 'Найдено $countString артистов',
      few: 'Найдено $countString артиста',
      one: 'Найден $countString артист',
    );
    return '$_temp0';
  }

  @override
  String get geniusFindArtist => 'Найти артиста на Genius';

  @override
  String get geniusArtistQueryHint => 'Например: Sugarcult';

  @override
  String get lyricsSyncingEllipsis => 'Синхронизация...';

  @override
  String get lyricsOffsetLabel => 'Сдвиг:';

  @override
  String lyricsOffsetValue(String value) {
    return '$value с';
  }

  @override
  String lyricsEarlierBy(String seconds) {
    return 'Лирика раньше на $seconds с';
  }

  @override
  String lyricsLaterBy(String seconds) {
    return 'Лирика позже на $seconds с';
  }

  @override
  String get tagEditorChooseCoverImageDialog => 'Выберите изображение обложки';

  @override
  String get tagEditorTitle => 'Редактирование тегов';

  @override
  String get tagEditorPlayingWarning =>
      'Этот трек сейчас играет. Запись может быть заблокирована — поставьте на паузу.';

  @override
  String get tagEditorTitleField => 'Название';

  @override
  String get tagEditorArtist => 'Исполнитель';

  @override
  String get tagEditorAlbum => 'Альбом';

  @override
  String get tagEditorAlbumArtist => 'Исполнитель альбома';

  @override
  String get tagEditorYear => 'Год';

  @override
  String get tagEditorTrackNumber => '№ трека';

  @override
  String get tagEditorDiscNumber => '№ диска';

  @override
  String get tagEditorGenre => 'Жанр';

  @override
  String get tagEditorSaving => 'Сохранение…';

  @override
  String get tagEditorChooseCover => 'Выбрать обложку';

  @override
  String get tagEditorRevertCover => 'Вернуть исходную';

  @override
  String get commonBack => 'Назад';

  @override
  String get playlistEmptyMessage =>
      'Плейлист пуст. Добавьте треки через контекстное меню в библиотеке.';

  @override
  String get playlistLabel => 'ПЛЕЙЛИСТ';

  @override
  String get playlistListen => 'Слушать';

  @override
  String get playlistShuffle => 'Перемешать';

  @override
  String get playlistCoverTooltip => 'Обложка';

  @override
  String get libraryAddFolder => 'Добавить папку';

  @override
  String get libraryRemoveFolderTitle => 'Удалить папку?';

  @override
  String libraryRemoveFolderConfirm(String path) {
    return 'Папка «$path» будет удалена из отслеживаемых, а её треки — из библиотеки.';
  }

  @override
  String get libraryTabTracks => 'Треки';

  @override
  String get libraryTabAlbums => 'Альбомы';

  @override
  String get libraryTabArtists => 'Артисты';

  @override
  String get libraryTabFolders => 'Папки';

  @override
  String get libraryNoFolders => 'Нет добавленных папок';

  @override
  String libraryArtistAlbumsAndTracks(String albums, String tracks) {
    return '$albums • $tracks';
  }

  @override
  String get favoritesNoTracks => 'Пока нет любимых треков';

  @override
  String get favoritesNoAlbums => 'Пока нет любимых альбомов';

  @override
  String get favoritesNoArtists => 'Пока нет любимых артистов';

  @override
  String get artistLabel => 'АРТИСТ';

  @override
  String artistDataFetched(String name) {
    return 'Подтянуты данные «$name»';
  }

  @override
  String get albumLabel => 'АЛЬБОМ';

  @override
  String get albumNoTracks => 'Нет треков';

  @override
  String get searchHint => 'Трек, артист или альбом…';

  @override
  String get searchHistoryEmpty => 'Здесь будут ваши недавние запросы';

  @override
  String get searchHistoryTitle => 'История';

  @override
  String searchResultsFound(int count) {
    return 'Найдено: $count';
  }

  @override
  String get trackPlay => 'Воспроизвести';

  @override
  String get trackAddToQueue => 'Добавить в очередь';

  @override
  String get trackAddToPlaylistEllipsis => 'Добавить в плейлист…';

  @override
  String get trackEditTagsEllipsis => 'Редактировать теги…';

  @override
  String trackAddedToQueue(String title) {
    return '«$title» добавлен в очередь';
  }

  @override
  String trackAddedToFavorites(String title) {
    return '«$title» добавлен в любимое';
  }

  @override
  String trackRemovedFromFavorites(String title) {
    return '«$title» убран из любимого';
  }

  @override
  String get trackListEmpty => 'Тут пока пусто';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes мин';
  }
}
