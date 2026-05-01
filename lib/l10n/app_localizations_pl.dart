// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get filterChipAll => 'Wszystkie linie';

  @override
  String filterChipSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linii',
      many: '$count linii',
      few: '$count linie',
      one: '$count linia',
    );
    return '$_temp0';
  }

  @override
  String get filterTitle => 'Filtruj linie';

  @override
  String get filterSearchPlaceholder => 'Szukaj linii…';

  @override
  String get filterTabTram => 'Tramwaje';

  @override
  String get filterTabBus => 'Autobusy';

  @override
  String get filterApply => 'Zastosuj';

  @override
  String get filterClear => 'Wyczyść';

  @override
  String mapLastUpdate(int seconds) {
    return 'aktualizacja: ${seconds}s temu';
  }

  @override
  String get mapLoading => 'Ładowanie pozycji…';

  @override
  String get mapOffline => 'Brak połączenia, ponawiam…';

  @override
  String markerTram(String number) {
    return 'Tramwaj $number';
  }

  @override
  String markerBus(String number) {
    return 'Autobus $number';
  }

  @override
  String markerUnknown(String number) {
    return 'Linia $number';
  }

  @override
  String markerAgo(int seconds) {
    return '${seconds}s temu';
  }

  @override
  String get permissionsLocationDenied => 'Brak dostępu do lokalizacji';

  @override
  String get appTitle => 'Łódź Transit';

  @override
  String get searchPlaceholder => 'Szukaj linii…';

  @override
  String get navMap => 'Mapa';

  @override
  String get navLines => 'Linie';

  @override
  String get navFavorites => 'Ulubione';

  @override
  String get screenComingSoon => 'Wkrótce';
}
