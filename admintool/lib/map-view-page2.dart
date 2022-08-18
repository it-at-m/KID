import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'markerdemo-contextmenubuilder.dart';
import 'markerdemo-datastore.dart';
import 'package:mapsforge_flutter/core.dart';
import 'package:mapsforge_flutter/datastore.dart';
import 'package:mapsforge_flutter/maps.dart';

import 'map-file-data.dart';

/// The [StatefulWidget] displaying the interactive map page. This is a demo
/// implementation for using mapsforge's [MapviewWidget].
///
class MapViewPage2 extends StatefulWidget {
  final MapFileData mapFileData;

  final MapDataStore? mapFile;

  const MapViewPage2(
      {Key? key, required this.mapFileData, required this.mapFile})
      : super(key: key);

  @override
  MapViewPageState2 createState() => MapViewPageState2();
}

/////////////////////////////////////////////////////////////////////////////

/// The [State] of the [MapViewPage] Widget.
class MapViewPageState2 extends State<MapViewPage2> {
  final DisplayModel displayModel = DisplayModel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildHead(context) as PreferredSizeWidget,
      body: _buildMapViewBody(context),
      drawer: Drawer(
          child: Column(
            children: [
              const Text('Navigation'),
              ListTile(
                title: const Text('Home'),
                onTap: () => Navigator.pushNamed(context, '/'),
              ),
              ListTile(
                title: const Text('Debug'),
                onTap: () => Navigator.pushNamed(context, '/debug'),
              )
            ],
          )
      ),
    );
  }

  /// Constructs the [AppBar] of the [MapViewPage] page.
  Widget _buildHead(BuildContext context) {
    return AppBar(
      title: Text(widget.mapFileData.displayedName),
    );
  }

  /// Constructs the body ([FlutterMapView]) of the [MapViewPage].
  Widget _buildMapViewBody(BuildContext context) {
    return MapviewWidget(
        displayModel: displayModel,
        createMapModel: () async {
          /// instantiate the job renderer. This renderer is the core of the system and retrieves or renders the tile-bitmaps
          return widget.mapFileData.mapType == MAPTYPE.OFFLINE
              ? await _createOfflineMapModel()
              : await _createOnlineMapModel();
        },
        createViewModel: () async {
          return _createViewModel();
        });
  }

  ViewModel _createViewModel() {
    // in this demo we use the markers only for offline databases.
    ViewModel viewModel = ViewModel(
      displayModel: displayModel,
      contextMenuBuilder: widget.mapFileData.mapType == MAPTYPE.OFFLINE
          ? MarkerdemoContextMenuBuilder()
          : const DefaultContextMenuBuilder(),
    );
    if (widget.mapFileData.indoorZoomOverlay)
      viewModel.addOverlay(IndoorlevelZoomOverlay(viewModel,
          indoorLevels: widget.mapFileData.indoorLevels));
    else
      viewModel.addOverlay(ZoomOverlay(viewModel));
    viewModel.addOverlay(DistanceOverlay(viewModel));
    //viewModel.addOverlay(DemoOverlay(viewModel: viewModel));

    // set default position
    viewModel.setMapViewPosition(widget.mapFileData.initialPositionLat,
        widget.mapFileData.initialPositionLong);
    viewModel.setZoomLevel(widget.mapFileData.initialZoomLevel);
    return viewModel;
  }

  Future<MapModel> _createOfflineMapModel() async {
    /// For the offline-maps we need a cache for all the tiny symbols in the map
    final SymbolCache symbolCache;
    if (kIsWeb) {
      symbolCache = MemorySymbolCache(bundle: rootBundle);
    } else {
      symbolCache =
          FileSymbolCache(rootBundle, widget.mapFileData.relativePathPrefix);
    }

    /// Prepare the Themebuilder. This instructs the renderer how to draw the images
    RenderTheme renderTheme =
        await RenderThemeBuilder.create(displayModel, widget.mapFileData.theme);

    /// instantiate the job renderer. This renderer is the core of the system and retrieves or renders the tile-bitmaps
    final JobRenderer jobRenderer =
        MapDataStoreRenderer(widget.mapFile!, renderTheme, symbolCache, true);

    /// and now it is similar to online rendering.

    /// provide the cache for the tile-bitmaps. In Web-mode we use an in-memory-cache
    final TileBitmapCache bitmapCache;
    if (kIsWeb) {
      bitmapCache = MemoryTileBitmapCache.create();
    } else {
      bitmapCache =
          await FileTileBitmapCache.create(jobRenderer.getRenderKey());
    }

    /// Now we can glue together and instantiate the mapModel and the viewModel. The former holds the
    /// properties for the map and the latter holds the properties for viewing the map
    MapModel mapModel = MapModel(
      displayModel: displayModel,
      renderer: jobRenderer,
      tileBitmapCache: bitmapCache,
      symbolCache: symbolCache,
    );
    mapModel.markerDataStores
        .add(MarkerdemoDatastore(symbolCache: symbolCache));

    return mapModel;
  }

  Future<MapModel> _createOnlineMapModel() async {
    /// instantiate the job renderer. This renderer is the core of the system and retrieves or renders the tile-bitmaps
    JobRenderer jobRenderer = widget.mapFileData.mapType == MAPTYPE.OSM
        ? MapOnlineRendererWeb()
        : ArcGisOnlineRenderer();

    /// provide the cache for the tile-bitmaps. In Web-mode we use an in-memory-cache
    final TileBitmapCache bitmapCache;
    if (kIsWeb) {
      bitmapCache = MemoryTileBitmapCache.create();
    } else {
      bitmapCache =
          await FileTileBitmapCache.create(jobRenderer.getRenderKey());
    }

    /// Now we can glue together and instantiate the mapModel and the viewModel. The former holds the
    /// properties for the map and the latter holds the properties for viewing the map
    MapModel mapModel = MapModel(
      displayModel: displayModel,
      renderer: jobRenderer,
      tileBitmapCache: bitmapCache,
    );
    return mapModel;
  }
}
