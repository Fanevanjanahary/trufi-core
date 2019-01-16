import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

import 'package:trufi_app/blocs/favorite_locations_bloc.dart';
import 'package:trufi_app/blocs/history_locations_bloc.dart';
import 'package:trufi_app/blocs/location_provider_bloc.dart';
import 'package:trufi_app/blocs/location_search_bloc.dart';
import 'package:trufi_app/blocs/request_manager_bloc.dart';
import 'package:trufi_app/pages/choose_location.dart';
import 'package:trufi_app/trufi_localizations.dart';
import 'package:trufi_app/trufi_models.dart';
import 'package:trufi_app/widgets/alerts.dart';
import 'package:trufi_app/widgets/favorite_button.dart';

class LocationSearchDelegate extends SearchDelegate<TrufiLocation> {
  LocationSearchDelegate({this.currentLocation});

  final TrufiLocation currentLocation;

  dynamic _result;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      primaryColor: Colors.white,
      primaryIconTheme: theme.primaryIconTheme.copyWith(color: Colors.black54),
      textTheme: theme.primaryTextTheme.copyWith(
        title: theme.primaryTextTheme.body1.copyWith(color: Colors.black),
        body1: theme.primaryTextTheme.body1.copyWith(color: Colors.black),
        body2: theme.primaryTextTheme.body2.copyWith(color: theme.accentColor),
      ),
    );
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(
        Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
      ),
      tooltip: "Back",
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _SuggestionList(
      query: query,
      onSelected: (TrufiLocation suggestion) {
        _result = suggestion;
        close(context, _result);
      },
      onMapTapped: (TrufiLocation location) {
        _result = location;
        showResults(context);
      },
      onStreetTapped: (TrufiStreet street) {
        _result = street;
        showResults(context);
      },
      currentLocation: currentLocation,
      historyLocationsBloc: HistoryLocationsBloc.of(context),
      favoriteLocationsBloc: FavoriteLocationsBloc.of(context),
      locationSearchBloc: LocationSearchBloc.of(context),
      appBarTheme: appBarTheme(context),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final localizations = TrufiLocalizations.of(context);
    if (_result != null) {
      if (_result is TrufiLocation) {
        print("${localizations.searchNavigate} ${_result.description}");
        Future.delayed(Duration.zero, () {
          close(context, _result);
        });
      }
      if (_result is TrufiStreet) {
        return _buildStreetResults(context, _result);
      }
    }
    return buildSuggestions(context);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return <Widget>[
      query.isEmpty
          ? IconButton(
              icon: const Icon(null),
              onPressed: () {},
            )
          : IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                query = '';
                showSuggestions(context);
              },
            ),
    ];
  }

  Widget _buildStreetResults(BuildContext context, TrufiStreet street) {
    List<Widget> slivers = List();
    slivers.add(SliverPadding(padding: EdgeInsets.all(4.0)));
    slivers.add(_buildStreetResultList(context, street));
    slivers.add(SliverPadding(padding: EdgeInsets.all(4.0)));
    return SafeArea(
      bottom: false,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        child: CustomScrollView(slivers: slivers),
      ),
    );
  }

  Widget _buildStreetResultList(
    BuildContext context,
    TrufiStreet street,
  ) {
    final favoriteLocationsBloc = FavoriteLocationsBloc.of(context);
    final historyLocationBloc = HistoryLocationsBloc.of(context);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Center
          if (index == 0) {
            return _buildItem(
              context,
              appBarTheme(context),
              () {
                historyLocationBloc.inAddLocation.add(street.location);
                close(context, street.location);
              },
              Icons.location_on,
              street.description,
              trailing: FavoriteButton(
                location: street.location,
                favoritesStream: favoriteLocationsBloc.outLocations,
                color: appBarTheme(context).primaryIconTheme.color,
              ),
            );
          }
          // Junctions
          final junction = street.junctions[index - 1];
          return _buildItem(
            context,
            appBarTheme(context),
            () {
              historyLocationBloc.inAddLocation.add(junction.location);
              close(context, junction.location);
            },
            Icons.location_on,
            "... y ${junction.street2.description}",
            trailing: FavoriteButton(
              location: junction.location,
              favoritesStream: favoriteLocationsBloc.outLocations,
              color: appBarTheme(context).primaryIconTheme.color,
            ),
          );
        },
        childCount: street.junctions.length + 1,
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  _SuggestionList({
    this.query,
    this.onSelected,
    this.onMapTapped,
    this.onStreetTapped,
    this.currentLocation,
    @required this.historyLocationsBloc,
    @required this.favoriteLocationsBloc,
    @required this.locationSearchBloc,
    @required this.appBarTheme,
  });

  final HistoryLocationsBloc historyLocationsBloc;
  final FavoriteLocationsBloc favoriteLocationsBloc;
  final LocationSearchBloc locationSearchBloc;
  final String query;
  final ValueChanged<TrufiLocation> onSelected;
  final ValueChanged<TrufiLocation> onMapTapped;
  final ValueChanged<TrufiStreet> onStreetTapped;
  final TrufiLocation currentLocation;
  final ThemeData appBarTheme;

  @override
  Widget build(BuildContext context) {
    List<Widget> slivers = List();
    slivers.add(SliverPadding(padding: EdgeInsets.all(4.0)));
    slivers.add(_buildYourLocation(context));
    slivers.add(_buildChooseOnMap(context));
    if (query.isEmpty) {
      slivers.add(_buildHistoryList(context));
      slivers.add(_buildFavoritesList(context));
      slivers.add(_buildPlacesList(context));
    } else {
      slivers.add(_buildSearchResultList(context));
    }
    slivers.add(SliverPadding(padding: EdgeInsets.all(4.0)));
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        child: CustomScrollView(slivers: slivers),
      ),
    );
  }

  Widget _buildYourLocation(BuildContext context) {
    final localizations = TrufiLocalizations.of(context);
    return SliverToBoxAdapter(
      child: _buildItem(
        context,
        appBarTheme,
        () => _handleOnYourLocationTapped(context),
        Icons.gps_fixed,
        localizations.searchItemYourLocation,
      ),
    );
  }

  Widget _buildChooseOnMap(BuildContext context) {
    final localizations = TrufiLocalizations.of(context);
    return SliverToBoxAdapter(
      child: _buildItem(
        context,
        appBarTheme,
        () => _handleOnChooseOnMapTapped(context),
        Icons.location_on,
        localizations.searchItemChooseOnMap,
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    final localizations = TrufiLocalizations.of(context);
    return _buildFutureBuilder(
      context,
      localizations.searchTitleRecent,
      historyLocationsBloc.fetchWithLimit(context, 5),
      Icons.history,
    );
  }

  Widget _buildFavoritesList(BuildContext context) {
    final localizations = TrufiLocalizations.of(context);
    return StreamBuilder(
      stream: favoriteLocationsBloc.outLocations,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<TrufiLocation>> snapshot,
      ) {
        return _buildObjectList(
          localizations.searchTitleFavorites,
          Icons.location_on,
          favoriteLocationsBloc.locations,
        );
      },
    );
  }

  Widget _buildPlacesList(BuildContext context) {
    final localizations = TrufiLocalizations.of(context);
    return _buildFutureBuilder(
      context,
      localizations.searchTitlePlaces,
      locationSearchBloc.fetchPlaces(context),
      Icons.place,
    );
  }

  Widget _buildSearchResultList(BuildContext context) {
    final requestManagerBloc = RequestManagerBloc.of(context);
    final localizations = TrufiLocalizations.of(context);
    return _buildFutureBuilder(
      context,
      localizations.searchTitleResults,
      requestManagerBloc.fetchLocations(context, query, 30),
      Icons.location_on,
      isVisibleWhenEmpty: true,
    );
  }

  Widget _buildFutureBuilder(
    BuildContext context,
    String title,
    Future<List<dynamic>> future,
    IconData iconData, {
    bool isVisibleWhenEmpty = false,
  }) {
    return FutureBuilder(
      future: future,
      initialData: null,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<dynamic>> snapshot,
      ) {
        final localizations = TrufiLocalizations.of(context);
        // Error
        if (snapshot.hasError) {
          print(snapshot.error);
          String error = localizations.commonUnknownError;
          if (snapshot.error is FetchOfflineRequestException) {
            error = "Offline mode is not implemented yet";
          } else if (snapshot.error is FetchOfflineResponseException) {
            error = "Offline mode is not implemented yet";
          } else if (snapshot.error is FetchOnlineRequestException) {
            error = localizations.commonNoInternet;
          } else if (snapshot.error is FetchOnlineResponseException) {
            error = localizations.commonFailLoading;
          }
          return _buildErrorList(context, title, error);
        }
        // Loading
        if (snapshot.data == null) {
          return SliverToBoxAdapter(
            child: LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Theme.of(context).accentColor),
            ),
          );
        }
        // No results
        int count = snapshot.data.length > 0 ? snapshot.data.length + 1 : 0;
        if (count == 0 && isVisibleWhenEmpty) {
          return SliverToBoxAdapter(
            child: Column(
              children: <Widget>[
                _buildTitle(context, title),
                _buildErrorItem(context, localizations.searchItemNoResults),
              ],
            ),
          );
        }
        // Items
        return _buildObjectList(title, iconData, snapshot.data);
      },
    );
  }

  Widget _buildErrorList(BuildContext context, String title, String error) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildTitle(context, title),
          _buildErrorItem(context, error),
        ],
      ),
    );
  }

  Widget _buildObjectList(
    String title,
    IconData iconData,
    List<dynamic> objects,
  ) {
    int count = objects.length > 0 ? objects.length + 1 : 0;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Title
          if (index == 0) {
            return _buildTitle(context, title);
          }
          // Item
          final object = objects[index - 1];
          if (object is TrufiLocation) {
            return _buildItem(
              context,
              appBarTheme,
              () => _handleOnLocationTapped(object, addToHistory: true),
              iconData,
              object.description,
              trailing: FavoriteButton(
                location: object,
                favoritesStream: favoriteLocationsBloc.outLocations,
                color: appBarTheme.primaryIconTheme.color,
              ),
            );
          } else if (object is TrufiStreet) {
            return _buildItem(
              context,
              appBarTheme,
              () => _handleOnStreetTapped(object),
              iconData,
              object.location.description,
              trailing: Icon(
                Icons.keyboard_arrow_right,
                color: appBarTheme.primaryIconTheme.color,
              ),
            );
          }
        },
        childCount: count,
      ),
    );
  }

  Widget _buildTitle(BuildContext context, String title) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
      child: Row(
        children: <Widget>[
          Container(padding: EdgeInsets.all(4.0)),
          RichText(
            text: TextSpan(
              text: title.toUpperCase(),
              style: appBarTheme.textTheme.body2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorItem(BuildContext context, String title) {
    return _buildItem(context, appBarTheme, null, Icons.error, title);
  }

  void _handleOnYourLocationTapped(BuildContext context) async {
    final locationProviderBloc = LocationProviderBloc.of(context);
    LatLng lastLocation = await locationProviderBloc.lastLocation;
    if (lastLocation != null) {
      _handleOnLatLngTapped(
        description: TrufiLocalizations.of(context).searchMapMarker,
        location: lastLocation,
        addToHistory: false,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => buildAlertLocationServicesDenied(context),
    );
  }

  void _handleOnChooseOnMapTapped(BuildContext context) async {
    final localizations = TrufiLocalizations.of(context);
    LatLng mapLocation = await Navigator.of(context).push(
      MaterialPageRoute<LatLng>(
        builder: (context) => ChooseLocationPage(
              initialPosition: currentLocation != null
                  ? LatLng(
                      currentLocation.latitude,
                      currentLocation.longitude,
                    )
                  : null,
            ),
      ),
    );
    _handleOnMapTapped(
      description: localizations.searchMapMarker,
      location: mapLocation,
    );
  }

  void _handleOnLatLngTapped({
    @required String description,
    @required LatLng location,
    bool addToHistory,
  }) {
    _handleOnLocationTapped(
      TrufiLocation(
        description: description,
        latitude: location.latitude,
        longitude: location.longitude,
      ),
      addToHistory: addToHistory,
    );
  }

  void _handleOnLocationTapped(
    TrufiLocation value, {
    bool addToHistory,
  }) {
    if (value != null) {
      if (addToHistory) {
        historyLocationsBloc.inAddLocation.add(value);
      }
      if (onSelected != null) {
        onSelected(value);
      }
    }
  }

  void _handleOnMapTapped({String description, LatLng location}) {
    if (location != null) {
      if (onMapTapped != null) {
        onMapTapped(TrufiLocation.fromLatLng(description, location));
      }
    }
  }

  void _handleOnStreetTapped(TrufiStreet street) {
    if (street != null) {
      if (onStreetTapped != null) {
        onStreetTapped(street);
      }
    }
  }
}

final _abbreviation = {
  "Avenida": "Av.",
  "Calle": "C.",
  "Camino": "C.º",
};

Widget _buildItem(
  BuildContext context,
  ThemeData theme,
  Function onTap,
  IconData iconData,
  String title, {
  Widget trailing,
}) {
  _abbreviation.forEach((from, replace) {
    title = title.replaceAll(from, replace);
  });
  Row row = Row(
    children: <Widget>[
      Icon(iconData, color: theme.primaryIconTheme.color),
      Container(width: 32.0),
      Expanded(
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.clip,
          text: TextSpan(text: title, style: theme.textTheme.body1),
        ),
      ),
    ],
  );
  if (trailing != null) {
    row.children.add(trailing);
  }
  return InkWell(
    onTap: onTap,
    child: Container(margin: EdgeInsets.all(8.0), child: row),
  );
}
