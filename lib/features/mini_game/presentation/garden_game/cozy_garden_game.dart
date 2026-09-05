import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../../auth/data/local_account_store.dart';
import 'components/ambient_components.dart';
import 'components/garden_background_component.dart';
import 'components/garden_decoration_component.dart';
import 'components/garden_foreground_details_component.dart';
import 'components/garden_mascot_component.dart';
import 'components/garden_terrain_component.dart';
import 'components/main_plant_component.dart';
import 'components/watering_effect_component.dart';
import 'garden_scene_state.dart';

class CozyGardenGame extends FlameGame {
  CozyGardenGame() {
    // The app keeps Flutter assets at assets/garden and assets/pets.
    images.prefix = '';
  }

  GardenBackgroundComponent? _background;
  GardenCloudComponent? _leftCloud;
  GardenCloudComponent? _rightCloud;
  GardenTerrainComponent? _terrain;
  GardenForegroundDetailsComponent? _foregroundDetails;
  GardenButterflyComponent? _butterfly;
  GardenBeeComponent? _bee;
  GardenAmbientParticles? _ambientParticles;
  MainPlantComponent? _plant;
  GardenMascotComponent? _pippa;
  GardenMascotComponent? _kebo;
  WateringEffectComponent? _wateringEffect;
  final Map<String, GardenDecorationComponent> _decorations = {};

  bool _loaded = false;
  bool _hasGardenState = false;
  bool _hasWatered = false;
  bool _partnerWatered = false;
  bool _bothWatered = false;
  bool _pendingBothWateredCelebration = false;
  bool _isDisposed = false;
  bool _reducedMotion = false;
  AccountMascot? _pendingWateringMascot;
  int _growth = 0;
  String _plantType = 'sunflower';
  AccountMascot _currentMascot = AccountMascot.panda;
  AccountMascot _partnerMascot = AccountMascot.koala;
  GardenGrowthStage _stage = GardenGrowthStage.seed;
  GardenTimeOfDay _timeOfDay = gardenTimeOfDayFor(DateTime.now());
  Set<String> _unlockedDecorations = <String>{};
  double _timeCheckElapsed = 0;

  @override
  Color backgroundColor() => const Color(0xFFBDE3A5);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final backgroundSprite =
        await _loadSprite('assets/garden/garden_scene.png');
    if (_isDisposed) return;
    final plantSprites = <GardenGrowthStage, Sprite?>{};
    for (final stage in GardenGrowthStage.values) {
      plantSprites[stage] = await _loadSprite(stage.assetPath);
      if (_isDisposed) return;
    }
    final pippaSprite =
        await _loadPetSprite('assets/pets/pippa/spritesheet.webp', 3);
    if (_isDisposed) return;
    final keboSprite =
        await _loadPetSprite('assets/pets/kebo/spritesheet.webp', 4);
    if (_isDisposed) return;

    _background = GardenBackgroundComponent(
      sceneSprite: backgroundSprite,
      timeOfDay: _timeOfDay,
    );
    _leftCloud = GardenCloudComponent(
      relativeX: -.18,
      relativeY: .1,
      speedFactor: .014,
    );
    _rightCloud = GardenCloudComponent(
      relativeX: .6,
      relativeY: .21,
      speedFactor: .009,
    );
    _terrain = GardenTerrainComponent(timeOfDay: _timeOfDay);
    _foregroundDetails = GardenForegroundDetailsComponent(
      timeOfDay: _timeOfDay,
    );
    _butterfly = GardenButterflyComponent();
    _bee = GardenBeeComponent();
    _ambientParticles = GardenAmbientParticles();
    _plant = MainPlantComponent(sprites: plantSprites);
    _pippa = GardenMascotComponent(
      name: 'Pippa',
      sprite: pippaSprite,
      fallbackColor: const Color(0xFFF5F2EA),
      isLeft: true,
    );
    _kebo = GardenMascotComponent(
      name: 'Kebo',
      sprite: keboSprite,
      fallbackColor: const Color(0xFFD5D3DD),
      isLeft: false,
    );

    await addAll([
      _background!,
      _leftCloud!,
      _rightCloud!,
      _terrain!,
      _butterfly!,
      _bee!,
      _foregroundDetails!,
      _plant!,
      _pippa!,
      _kebo!,
      _ambientParticles!,
    ]);
    if (_isDisposed) {
      dispose();
      return;
    }
    _loaded = true;
    _syncDecorations();
    _layoutScene();
    // The widget layer may have reported reduce-motion before load finished.
    _applyReducedMotionToComponents();
    _applyVisualState(animateGrowth: false);
    final pendingWateringMascot = _pendingWateringMascot;
    _pendingWateringMascot = null;
    if (pendingWateringMascot != null) playWatering(pendingWateringMascot);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutScene();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timeCheckElapsed += dt;
    if (_timeCheckElapsed < 30) return;
    refreshTimeOfDay();
  }

  void refreshTimeOfDay() {
    if (_isDisposed) return;
    _timeCheckElapsed = 0;
    final nextTimeOfDay = gardenTimeOfDayFor(DateTime.now());
    if (nextTimeOfDay == _timeOfDay) return;
    _timeOfDay = nextTimeOfDay;
    if (_loaded) _applyVisualState(animateGrowth: false);
  }

  /// Receives all shared-garden data from CozyGardenScreen. Flame does not
  /// own a Supabase subscription and never writes to the backend.
  void updateGardenState({
    required int growth,
    required String plantType,
    required AccountMascot currentMascot,
    required AccountMascot partnerMascot,
    required bool hasWatered,
    required bool partnerWatered,
    required Set<String> unlockedDecorations,
  }) {
    if (_isDisposed) return;
    final nextGrowth = growth.clamp(0, 100).toInt();
    final nextStage = GardenGrowthStage.fromGrowth(nextGrowth);
    final nextPlantType = plantType.trim().toLowerCase();
    final didPlantChange = _hasGardenState && nextPlantType != _plantType;
    final didGrowthChange =
        _hasGardenState && (nextGrowth != _growth || nextStage != _stage);
    final nextBothWatered = hasWatered && partnerWatered;
    final nextDecorations = Set<String>.from(unlockedDecorations);
    final didDecorationsChange =
        !_unlockedDecorations.containsAll(nextDecorations) ||
            !nextDecorations.containsAll(_unlockedDecorations);
    if (nextBothWatered && !_bothWatered) {
      _pendingBothWateredCelebration = true;
    }

    _growth = nextGrowth;
    _stage = nextStage;
    _plantType = nextPlantType;
    _currentMascot = currentMascot;
    _partnerMascot = partnerMascot;
    _hasWatered = hasWatered;
    _partnerWatered = partnerWatered;
    _bothWatered = nextBothWatered;
    _unlockedDecorations = nextDecorations;
    _hasGardenState = true;

    if (_loaded) {
      if (didDecorationsChange) _syncDecorations();
      _applyVisualState(animateGrowth: didGrowthChange || didPlantChange);
    }
  }

  /// Mirrors the platform "reduce motion" setting supplied by the widget layer.
  void setReducedMotion(bool value) {
    if (_isDisposed || _reducedMotion == value) return;
    _reducedMotion = value;
    _applyReducedMotionToComponents();
  }

  void _applyReducedMotionToComponents() {
    _leftCloud?.setReducedMotion(_reducedMotion);
    _rightCloud?.setReducedMotion(_reducedMotion);
    _butterfly?.setReducedMotion(_reducedMotion);
    _bee?.setReducedMotion(_reducedMotion);
    _plant?.setReducedMotion(_reducedMotion);
    _pippa?.setReducedMotion(_reducedMotion);
    _kebo?.setReducedMotion(_reducedMotion);
    _ambientParticles?.setReducedMotion(_reducedMotion);
    for (final decoration in _decorations.values) {
      decoration.setReducedMotion(_reducedMotion);
    }
  }

  void playWatering(AccountMascot wateringMascot) {
    if (_isDisposed) return;
    if (!_loaded || size.x <= 0 || size.y <= 0) {
      _pendingWateringMascot = wateringMascot;
      return;
    }
    cancelWatering();
    // Both mascots turn toward the plant for the duration of the pour.
    _pippa?.setWatchingPlant(true);
    _kebo?.setWatchingPlant(true);
    late final WateringEffectComponent effect;
    effect = WateringEffectComponent(
      sceneSize: size.clone(),
      target: Vector2(size.x * .5, size.y * .7),
      reducedMotion: _reducedMotion,
      onWaterHit: () {
        _plant?.reactToWater();
        if (wateringMascot == AccountMascot.panda) {
          _pippa?.cheer();
          _kebo?.celebrate();
        } else {
          _kebo?.cheer();
          _pippa?.celebrate();
        }
      },
      onFinished: () {
        _pippa?.setWatchingPlant(false);
        _kebo?.setWatchingPlant(false);
        if (identical(_wateringEffect, effect)) _wateringEffect = null;
      },
    );
    _wateringEffect = effect;
    add(effect);
  }

  void cancelWatering() {
    _pendingWateringMascot = null;
    _pippa?.setWatchingPlant(false);
    _kebo?.setWatchingPlant(false);
    _wateringEffect?.removeFromParent();
    _wateringEffect = null;
  }

  void playHarvestCelebration() {
    if (_isDisposed || !_loaded) return;
    _plant?.celebrate();
    _pippa?.cheer();
    _kebo?.cheer();
    _ambientParticles?.triggerCelebration();
  }

  @override
  void onDispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    cancelWatering();
    dispose();
    _loaded = false;
    _background = null;
    _leftCloud = null;
    _rightCloud = null;
    _terrain = null;
    _foregroundDetails = null;
    _butterfly = null;
    _bee = null;
    _ambientParticles = null;
    _plant = null;
    _pippa = null;
    _kebo = null;
    _decorations.clear();
    super.onDispose();
  }

  Future<Sprite?> _loadSprite(String path) async {
    if (_isDisposed) return null;
    try {
      final image = await images.load(path);
      if (_isDisposed) {
        if (images.containsKey(path)) {
          images.clear(path);
        } else {
          image.dispose();
        }
        return null;
      }
      final sprite = Sprite(image);
      sprite.paint.filterQuality = FilterQuality.none;
      return sprite;
    } catch (error) {
      if (!_isDisposed) {
        debugPrint('Cozy Garden could not load asset "$path": $error');
      }
      return null;
    }
  }

  Future<Sprite?> _loadPetSprite(String path, int row) async {
    if (_isDisposed) return null;
    try {
      final image = await images.load(path);
      if (_isDisposed) {
        if (images.containsKey(path)) {
          images.clear(path);
        } else {
          image.dispose();
        }
        return null;
      }
      final sprite = Sprite(
        image,
        srcPosition: Vector2(0, row * 208),
        srcSize: Vector2(192, 208),
      );
      sprite.paint.filterQuality = FilterQuality.none;
      return sprite;
    } catch (error) {
      if (!_isDisposed) {
        debugPrint('Cozy Garden could not load pet asset "$path": $error');
      }
      return null;
    }
  }

  void _layoutScene() {
    if (!_loaded || size.x <= 0 || size.y <= 0) return;
    _background!
      ..position.setZero()
      ..size.setFrom(size);
    _leftCloud!.layoutForScene(size);
    _rightCloud!.layoutForScene(size);
    _terrain!.layoutForScene(size);
    _foregroundDetails!.layoutForScene(size);
    _butterfly!.layoutForScene(size);
    _bee!.layoutForScene(size);
    _ambientParticles!.layoutForScene(size);
    for (final decoration in _decorations.values) {
      decoration.layoutForScene(size);
    }
    _plant!.layoutForScene(size);
    _pippa!.layoutForScene(size);
    _kebo!.layoutForScene(size);
  }

  void _syncDecorations() {
    if (!_loaded) return;
    final requested = _unlockedDecorations
        .where(GardenDecorationComponent.supportedIds.contains)
        .toSet();
    final removedIds = _decorations.keys
        .where((decorationId) => !requested.contains(decorationId))
        .toList();
    for (final decorationId in removedIds) {
      _decorations.remove(decorationId)?.removeFromParent();
    }
    for (final decorationId in requested) {
      if (_decorations.containsKey(decorationId)) continue;
      final decoration = GardenDecorationComponent(
        decorationId: decorationId,
        timeOfDay: _timeOfDay,
      );
      decoration.setReducedMotion(_reducedMotion);
      _decorations[decorationId] = decoration;
      add(decoration);
    }
    for (final decoration in _decorations.values) {
      decoration.layoutForScene(size);
    }
  }

  void _applyVisualState({required bool animateGrowth}) {
    _background?.updateTimeOfDay(_timeOfDay);
    _leftCloud?.updateTimeOfDay(_timeOfDay);
    _rightCloud?.updateTimeOfDay(_timeOfDay);
    _terrain?.updateTimeOfDay(_timeOfDay);
    _foregroundDetails?.updateTimeOfDay(_timeOfDay);
    for (final decoration in _decorations.values) {
      decoration.updateTimeOfDay(_timeOfDay);
    }
    _plant?.setPlantType(_plantType);
    _plant?.setStage(_stage);
    if (animateGrowth) _plant?.reactToGrowth();
    _pippa?.setWatered(_isMascotWatered(AccountMascot.panda));
    _kebo?.setWatered(_isMascotWatered(AccountMascot.koala));
    _bee?.setActive(_growth >= 65);
    _ambientParticles?.setConditions(timeOfDay: _timeOfDay, growth: _growth);
    if (_pendingBothWateredCelebration) {
      _pendingBothWateredCelebration = false;
      _plant?.celebrate();
      _pippa?.cheer();
      _kebo?.cheer();
      _ambientParticles?.triggerCelebration();
    }
  }

  bool _isMascotWatered(AccountMascot mascot) {
    return (_currentMascot == mascot && _hasWatered) ||
        (_partnerMascot == mascot && _partnerWatered);
  }
}
