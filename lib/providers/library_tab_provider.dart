import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/screens/library_tab.dart';

final libraryTabProvider =
    StateProvider<LibraryTab>((ref) => LibraryTab.tracks);

final libraryShowBackProvider = StateProvider<bool>((ref) => false);
