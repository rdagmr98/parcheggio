import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'formatters.dart';
import 'park_service.dart';
import 'theme.dart';
import 'widgets/glass_panel.dart';
import 'widgets/map_markers.dart';

/// Centro predefinito sull'Italia se né auto né utente sono ancora disponibili.
const LatLng _kDefaultItalyCenter = LatLng(42.5, 12.5);
const double _kDefaultItalyZoom = 5.6;
const double _kFocusSingleZoom = 17.0;
const double _kWideBreakpoint = 640.0;
const double _kSidePanelWidth = 352.0;

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({
    super.key,
    this.service = const ParkService(),
    this.tileProvider,
    this.clock,
  });

  final ParkService service;

  /// Consente di sostituire il TileProvider (es. nei widget test offline).
  final TileProvider? tileProvider;

  /// Sorgente temporale iniettabile per test deterministici.
  final DateTime Function()? clock;

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final TileProvider _tileProvider;
  late final bool _ownsTileProvider;

  late final AnimationController _panelEntranceController;
  late final Animation<double> _panelFade;
  late final Animation<Offset> _panelSlide;

  AnimationController? _cameraAnimController;
  Timer? _minuteTimer;

  ParkPoint? _parked;
  ParkPoint? _here;
  List<String> _missing = const [];

  bool _isLoadingInitial = true;
  bool _isLocatingHere = false;
  bool _isMarking = false;
  bool _mapReady = false;
  bool _hasAutoFramed = false;
  bool _hasFramedBoth = false;
  bool? _lastIsWide;

  int _hereRequestSeq = 0;
  int _getRequestSeq = 0;
  DateTime _now = DateTime.now();

  DateTime _currentTime() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.tileProvider != null) {
      _tileProvider = widget.tileProvider!;
      _ownsTileProvider = false;
    } else {
      _tileProvider = NetworkTileProvider(silenceExceptions: true);
      _ownsTileProvider = true;
    }

    _now = _currentTime();

    _panelEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _panelFade = CurvedAnimation(
      parent: _panelEntranceController,
      curve: Curves.easeOutCubic,
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_panelFade);

    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = _currentTime();
      });
    });

    _refreshAll(reframeOnChange: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteTimer?.cancel();
    _cameraAnimController?.dispose();
    _panelEntranceController.dispose();
    _mapController.dispose();
    if (_ownsTileProvider) {
      _tileProvider.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll(reframeOnChange: false);
    }
  }

  /// Ricarica `get`, `missing` e `here` in parallelo senza mai bloccare la UI.
  void _refreshAll({required bool reframeOnChange}) {
    if (mounted) {
      setState(() {
        _now = _currentTime();
      });
    }
    unawaited(_loadParkedAndMissing(reframeOnChange: reframeOnChange));
    unawaited(_loadHere());
  }

  Future<void> _loadParkedAndMissing({required bool reframeOnChange}) async {
    final seq = ++_getRequestSeq;
    final results = await Future.wait<Object?>([
      widget.service.getParked(),
      widget.service.getMissing(),
    ]);
    if (!mounted || seq != _getRequestSeq) return;

    final parked = results[0] as ParkPoint?;
    final missing = results[1] as List<String>;
    final parkedChanged = parked != _parked;
    final wasLoadingInitial = _isLoadingInitial;

    setState(() {
      _parked = parked;
      _missing = missing;
      _isLoadingInitial = false;
      _now = _currentTime();
    });

    if (wasLoadingInitial && _panelEntranceController.status == AnimationStatus.dismissed) {
      _panelEntranceController.forward();
    }

    if (reframeOnChange || parkedChanged || !_hasAutoFramed) {
      if (parkedChanged) {
        _hasFramedBoth = false;
      }
      _scheduleFrameMap(animate: _hasAutoFramed);
    }
  }

  Future<void> _loadHere() async {
    final seq = ++_hereRequestSeq;
    if (mounted) {
      setState(() {
        _isLocatingHere = true;
      });
    }

    final here = await widget.service.getHere();
    if (!mounted || seq != _hereRequestSeq) return;

    setState(() {
      _here = here;
      _isLocatingHere = false;
      _now = _currentTime();
    });

    if (here != null) {
      final shouldFrameBoth = _parked != null && !_hasFramedBoth;
      final shouldFrameUserOnly = _parked == null && !_hasAutoFramed;
      if (shouldFrameBoth || shouldFrameUserOnly) {
        _scheduleFrameMap(animate: _hasAutoFramed);
      }
    }
  }

  Future<void> _handleMarkPressed() async {
    if (_isMarking) return;

    // Chiede conferma prima di sovrascrivere un parcheggio già esistente.
    if (_parked != null) {
      final confirmed = await showConfirmOverwriteDialog(
        context,
        existingDateTimeLabel: formatItalianDateTime(_parked!.time, _now),
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _isMarking = true;
    });

    final saved = await widget.service.markHere();
    if (!mounted) return;

    if (saved != null) {
      // Invalida eventuali risposte stale di `get` precedenti.
      _getRequestSeq++;
      setState(() {
        _parked = saved;
        _here = saved;
        _isMarking = false;
        _isLoadingInitial = false;
        _now = _currentTime();
      });
      _hasFramedBoth = false;
      _scheduleFrameMap(animate: true);
      _showToast('Posizione del parcheggio salvata');
    } else {
      setState(() {
        _isMarking = false;
      });
      _showToast('Posizione non disponibile. Riprova all\'aperto.');
    }
  }

  Future<void> _handleNavigatePressed() async {
    await widget.service.navigate();
  }

  Future<void> _handleFixPressed() async {
    await widget.service.fix();
  }

  void _showToast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        ),
      );
  }

  void _scheduleFrameMap({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _frameMap(animate: animate);
    });
  }

  void _cancelCameraAnimation() {
    _cameraAnimController?.stop();
    _cameraAnimController?.dispose();
    _cameraAnimController = null;
  }

  /// Inquadra auto e utente insieme se entrambi presenti, altrimenti l'unico
  /// punto disponibile, tenendo conto dello spazio occupato dal pannello UI.
  void _frameMap({required bool animate}) {
    if (!mounted || !_mapReady) return;

    final MapCamera currentCamera;
    try {
      currentCamera = _mapController.camera;
    } catch (_) {
      return;
    }

    final size = currentCamera.nonRotatedSize;
    if (size.width <= 0 || size.height <= 0) return;

    final isWide = size.width >= _kWideBreakpoint;
    final mediaPadding = MediaQuery.paddingOf(context);

    final parked = _parked;
    final here = _here;

    if (parked == null && here == null) {
      return;
    }

    _hasAutoFramed = true;

    // Padding asimmetrico per centrare i marker nella zona visibile della mappa.
    final EdgeInsets fitPadding = isWide
        ? EdgeInsets.fromLTRB(
            _kSidePanelWidth + 96,
            mediaPadding.top + 56,
            96,
            mediaPadding.bottom + 56,
          )
        : EdgeInsets.fromLTRB(
            80,
            mediaPadding.top + (_missing.isNotEmpty ? 150 : 88),
            80,
            (size.height * 0.42).clamp(280.0, 410.0) + mediaPadding.bottom,
          );

    // Calcola il punto/zoom obiettivo.
    LatLng targetCenter;
    double targetZoom;

    if (parked != null && here != null) {
      _hasFramedBoth = true;
      final dist = calculateDistanceMeters(parked.latLng, here.latLng);
      if (dist < 25) {
        final target = _offsetSinglePointCamera(
          camera: currentCamera,
          point: parked.latLng,
          zoom: _kFocusSingleZoom,
          fitPadding: fitPadding,
        );
        targetCenter = target.center;
        targetZoom = target.zoom;
      } else {
        final bounds = LatLngBounds.fromPoints([parked.latLng, here.latLng]);
        final fitted = CameraFit.bounds(
          bounds: bounds,
          padding: fitPadding,
          maxZoom: 17.5,
          minZoom: 4.0,
        ).fit(currentCamera);
        targetCenter = fitted.center;
        targetZoom = fitted.zoom;
      }
    } else {
      final point = (parked ?? here)!.latLng;
      final target = _offsetSinglePointCamera(
        camera: currentCamera,
        point: point,
        zoom: parked != null ? _kFocusSingleZoom : 16.2,
        fitPadding: fitPadding,
      );
      targetCenter = target.center;
      targetZoom = target.zoom;
    }

    if (!animate) {
      _cancelCameraAnimation();
      _mapController.move(targetCenter, targetZoom);
      return;
    }

    _animateCameraTo(currentCamera, targetCenter, targetZoom);
  }

  /// Calcola il centro della camera affinché [point] cada esattamente nel centro
  /// della porzione di mappa non coperta dal pannello.
  ({LatLng center, double zoom}) _offsetSinglePointCamera({
    required MapCamera camera,
    required LatLng point,
    required double zoom,
    required EdgeInsets fitPadding,
  }) {
    final shiftX = (fitPadding.right - fitPadding.left) / 2;
    final shiftY = (fitPadding.bottom - fitPadding.top) / 2;
    final projected = camera.projectAtZoom(point, zoom);
    final shifted = projected + Offset(shiftX, shiftY);
    return (center: camera.unprojectAtZoom(shifted, zoom), zoom: zoom);
  }

  void _animateCameraTo(
    MapCamera fromCamera,
    LatLng targetCenter,
    double targetZoom,
  ) {
    _cancelCameraAnimation();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _cameraAnimController = controller;

    final curve = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    final startCenter = fromCamera.center;
    final startZoom = fromCamera.zoom;

    controller.addListener(() {
      if (!mounted || !_mapReady) return;
      final t = curve.value;
      final lat = lerpDouble(startCenter.latitude, targetCenter.latitude, t)!;
      final lon = lerpDouble(startCenter.longitude, targetCenter.longitude, t)!;
      final zoom = lerpDouble(startZoom, targetZoom, t)!;
      _mapController.move(LatLng(lat, lon), zoom);
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (_cameraAnimController == controller) {
          _cameraAnimController = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgObsidian,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _kWideBreakpoint;
            if (_lastIsWide != null && _lastIsWide != isWide) {
              _scheduleFrameMap(animate: false);
            }
            _lastIsWide = isWide;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Mappa a tutto schermo (edge-to-edge).
                _buildMap(),

                // 2. Sfumatura superiore discreta per leggibilità status bar.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.paddingOf(context).top + 96,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.bgObsidian.withValues(alpha: 0.72),
                            AppColors.bgObsidian.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Overlay adattivo: pannello laterale su Fold aperto,
                //    pannello in basso su schermo esterno.
                if (isWide)
                  _buildWideOverlay(context, constraints)
                else
                  _buildNarrowOverlay(context, constraints),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap() {
    final parked = _parked;
    final here = _here;

    final circles = <CircleMarker>[
      if (here != null && here.acc > 0)
        CircleMarker(
          point: here.latLng,
          radius: here.acc.toDouble(),
          useRadiusInMeter: true,
          color: AppColors.userBlue.withValues(alpha: 0.10),
          borderColor: AppColors.userBlue.withValues(alpha: 0.28),
          borderStrokeWidth: 1,
        ),
      if (parked != null && parked.acc > 0)
        CircleMarker(
          point: parked.latLng,
          radius: parked.acc.toDouble(),
          useRadiusInMeter: true,
          color: AppColors.audiRed.withValues(alpha: 0.13),
          borderColor: AppColors.audiRed.withValues(alpha: 0.42),
          borderStrokeWidth: 1.2,
        ),
    ];

    final polylines = <Polyline>[
      if (parked != null &&
          here != null &&
          calculateDistanceMeters(parked.latLng, here.latLng) >= 15)
        Polyline(
          points: [here.latLng, parked.latLng],
          strokeWidth: 2.0,
          color: Colors.white.withValues(alpha: 0.26),
          pattern: const StrokePattern.dotted(spacingFactor: 2.6),
        ),
    ];

    final markers = <Marker>[
      if (here != null)
        Marker(
          point: here.latLng,
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: const UserLocationDot(),
        ),
      if (parked != null)
        Marker(
          point: parked.latLng,
          width: 88,
          height: 88,
          alignment: Alignment.center,
          child: const CarBeaconMarker(),
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _kDefaultItalyCenter,
        initialZoom: _kDefaultItalyZoom,
        minZoom: 3,
        maxZoom: 20,
        backgroundColor: AppColors.mapCanvas,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _mapReady = true;
          _scheduleFrameMap(animate: false);
        },
        onMapEvent: (event) {
          if (event.source != MapEventSource.mapController &&
              _cameraAnimController != null) {
            _cancelCameraAnimation();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.rdagmr98.parcheggio',
          maxNativeZoom: 20,
          maxZoom: 20,
          tileProvider: _tileProvider,
          tileDisplay: const TileDisplay.fadeIn(
            duration: Duration(milliseconds: 220),
          ),
        ),
        if (circles.isNotEmpty) CircleLayer(circles: circles),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }

  /// Layout per schermo stretto (es. esterno Galaxy Z Fold5 ~402x1029 dp):
  /// pannello in basso nella zona del pollice.
  Widget _buildNarrowOverlay(BuildContext context, BoxConstraints constraints) {
    final safePadding = MediaQuery.paddingOf(context);
    final usableHeight = constraints.maxHeight - safePadding.vertical;
    final reservedTop = _missing.isNotEmpty ? 220.0 : 148.0;
    final maxPanelHeight = (usableHeight - reservedTop).clamp(180.0, 560.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra superiore minimale + avviso permessi se necessario.
            Align(
              alignment: Alignment.centerLeft,
              child: BrandHeaderBadge(
                isBusy: _isLocatingHere && _parked == null && _here == null,
              ),
            ),
            if (_missing.isNotEmpty) ...[
              const SizedBox(height: 10),
              MissingPermissionsBanner(
                missing: _missing,
                onFix: _handleFixPressed,
              ),
            ],

            // Spazio libero per interagire con la mappa sottostante.
            const Spacer(),

            // Attribuzione discreta a sinistra e pulsante ricentra a destra,
            // subito sopra al pannello.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Flexible(child: AttributionBadge()),
                if (_parked != null || _here != null) ...[
                  const SizedBox(width: 12),
                  RecenterMapButton(onPressed: () => _frameMap(animate: true)),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Pannello principale con animazione di comparsa sobria.
            if (!_isLoadingInitial)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxPanelHeight),
                child: SlideTransition(
                  position: _panelSlide,
                  child: FadeTransition(
                    opacity: _panelFade,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ParkingInfoPanel(
                        parked: _parked,
                        here: _here,
                        now: _now,
                        isLocatingHere: _isLocatingHere,
                        isMarking: _isMarking,
                        onNavigate: _handleNavigatePressed,
                        onMark: _handleMarkPressed,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Layout per schermo ampio (es. interno Galaxy Z Fold5 ~805x967 dp):
  /// pannello laterale a sinistra e mappa aperta sulla destra.
  Widget _buildWideOverlay(BuildContext context, BoxConstraints constraints) {
    final safePadding = MediaQuery.paddingOf(context);
    final usableHeight = constraints.maxHeight - safePadding.vertical - 40;
    final reservedTop = _missing.isNotEmpty ? 168.0 : 84.0;
    final maxPanelHeight = (usableHeight - reservedTop).clamp(200.0, 620.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Colonna laterale sinistra: intestazione, eventuale avviso permessi
            // e pannello principale nella zona comoda del pollice sinistro.
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: _kSidePanelWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BrandHeaderBadge(
                        isBusy:
                            _isLocatingHere && _parked == null && _here == null,
                      ),
                    ),
                    if (_missing.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      MissingPermissionsBanner(
                        missing: _missing,
                        onFix: _handleFixPressed,
                      ),
                    ],
                    const Spacer(),
                    if (!_isLoadingInitial)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxPanelHeight),
                        child: SlideTransition(
                          position: _panelSlide,
                          child: FadeTransition(
                            opacity: _panelFade,
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: ParkingInfoPanel(
                                parked: _parked,
                                here: _here,
                                now: _now,
                                isLocatingHere: _isLocatingHere,
                                isMarking: _isMarking,
                                onNavigate: _handleNavigatePressed,
                                onMark: _handleMarkPressed,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Controllo ricentra + attribuzione in basso a destra sulla mappa.
            Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_parked != null || _here != null) ...[
                    RecenterMapButton(
                      onPressed: () => _frameMap(animate: true),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const AttributionBadge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
