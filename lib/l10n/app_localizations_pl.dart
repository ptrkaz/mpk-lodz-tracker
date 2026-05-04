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

  @override
  String nearbyStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count przystanków w pobliżu',
      many: '$count przystanków w pobliżu',
      few: '$count przystanki w pobliżu',
      one: '1 przystanek w pobliżu',
    );
    return '$_temp0';
  }

  @override
  String get nearbyEmptyNoStops => 'Brak przystanków w promieniu 500 m';

  @override
  String get nearbyEmptyNoDepartures => 'Brak nadchodzących odjazdów';

  @override
  String get nearbyWaitingForGps => 'Czekam na sygnał GPS…';

  @override
  String get nearbyCheckingLocation => 'Sprawdzam lokalizację…';

  @override
  String get permissionCtaTitleDenied =>
      'Włącz lokalizację, by zobaczyć przystanki w pobliżu';

  @override
  String get permissionCtaButtonGrant => 'Włącz lokalizację';

  @override
  String get permissionCtaButtonSettings => 'Otwórz ustawienia';

  @override
  String get permissionCtaTitleService =>
      'Włącz usługi lokalizacji w ustawieniach systemu';

  @override
  String walkMinutes(int n) {
    return '~$n min';
  }

  @override
  String metersAway(int n) {
    return '$n m';
  }

  @override
  String lastUpdatedAt(String time) {
    return 'ostatnia aktualizacja $time';
  }

  @override
  String delayLate(int n) {
    return '+$n min';
  }

  @override
  String delayEarly(int n) {
    return '−$n min';
  }
}
