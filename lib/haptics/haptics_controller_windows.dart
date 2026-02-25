/// Windows WinRT haptics implementation using `dart:ffi`.
///
/// Calls the following WinRT COM chain to enable the "ink-on-paper" friction
/// sensation on a Surface Slim Pen 2 (or any pen that exposes a
/// `SimpleHapticsController`):
///
///   1. `RoGetActivationFactory("Windows.UI.Input.PenDevice", IPenDeviceStatics)`
///   2. `IPenDeviceStatics::GetFromPointerId(pointerId)` → `IPenDevice`
///   3. `IPenDevice::QueryInterface(IPenDevice2)` → `IPenDevice2`
///   4. `IPenDevice2::get_SimpleHapticsController()` → `ISimpleHapticsController`
///   5. `ISimpleHapticsController::get_SupportedFeedback()` → iterate to find
///      `KnownSimpleHapticsControllerWaveforms::InkContinuous` (0x1007)
///   6. `ISimpleHapticsController::SendHapticFeedbackWithIntensity(feedback, intensity)`
///   7. `ISimpleHapticsController::StopFeedback()` when the pen is lifted
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'haptics_controller.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Waveform constants
// (Windows.Devices.Haptics.KnownSimpleHapticsControllerWaveforms)
// ═══════════════════════════════════════════════════════════════════════════

/// Continuous ink-writing waveform – produces the "friction on paper" feel.
const int _kWaveformInkContinuous = 0x1007;

/// Fallback continuous buzz waveform when InkContinuous is unsupported.
const int _kWaveformBuzzContinuous = 0x1004;

// ═══════════════════════════════════════════════════════════════════════════
// HRESULT helpers
// ═══════════════════════════════════════════════════════════════════════════

/// Returns `true` when an HRESULT value indicates success (S_OK or S_FALSE).
bool _succeeded(int hr) => hr >= 0;

// ═══════════════════════════════════════════════════════════════════════════
// FFI – COM / WinRT struct definitions
// ═══════════════════════════════════════════════════════════════════════════

/// Placeholder native function type used as the vtable slot element type.
/// Each slot is individually cast to the concrete signature before calling.
typedef _AnyNativeFunc = Void Function();

/// COM/WinRT object layout: the first (and only) field is a pointer to the
/// virtual-function table (vtable).
final class _COMObject extends Struct {
  external Pointer<Pointer<NativeFunction<_AnyNativeFunc>>> lpVtbl;
}

/// Windows `GUID` / `IID` layout.
final class _GUID extends Struct {
  @Uint32()
  external int data1;
  @Uint16()
  external int data2;
  @Uint16()
  external int data3;
  @Array(8)
  external Array<Uint8> data4;
}

// ═══════════════════════════════════════════════════════════════════════════
// FFI – native function typedefs (one pair per WinRT method we call)
// ═══════════════════════════════════════════════════════════════════════════

// IUnknown::QueryInterface  (vtable index 0)
typedef _QueryInterfaceN = Int32 Function(
    Pointer<_COMObject>, Pointer<_GUID>, Pointer<Pointer<_COMObject>>);
typedef _QueryInterfaceD = int Function(
    Pointer<_COMObject>, Pointer<_GUID>, Pointer<Pointer<_COMObject>>);

// IUnknown::Release  (vtable index 2)
typedef _ReleaseN = Uint32 Function(Pointer<_COMObject>);
typedef _ReleaseD = int Function(Pointer<_COMObject>);

// WindowsCreateString – creates an HSTRING from a wide-character buffer.
typedef _WindowsCreateStringN = Int32 Function(
    Pointer<Utf16>, Uint32, Pointer<IntPtr>);
typedef _WindowsCreateStringD = int Function(
    Pointer<Utf16>, int, Pointer<IntPtr>);

// WindowsDeleteString – releases an HSTRING.
typedef _WindowsDeleteStringN = Int32 Function(IntPtr);
typedef _WindowsDeleteStringD = int Function(int);

// RoInitialize – initialises the WinRT runtime on the calling thread.
typedef _RoInitializeN = Int32 Function(Int32);
typedef _RoInitializeD = int Function(int);

// RoGetActivationFactory – returns an activation factory for a WinRT class.
typedef _RoGetActivationFactoryN = Int32 Function(
    IntPtr, Pointer<_GUID>, Pointer<Pointer<_COMObject>>);
typedef _RoGetActivationFactoryD = int Function(
    int, Pointer<_GUID>, Pointer<Pointer<_COMObject>>);

// IPenDeviceStatics::GetFromPointerId  (vtable index 6)
typedef _GetFromPointerIdN = Int32 Function(
    Pointer<_COMObject>, Uint32, Pointer<Pointer<_COMObject>>);
typedef _GetFromPointerIdD = int Function(
    Pointer<_COMObject>, int, Pointer<Pointer<_COMObject>>);

// IPenDevice2::get_SimpleHapticsController  (vtable index 6)
typedef _GetHapticsControllerN = Int32 Function(
    Pointer<_COMObject>, Pointer<Pointer<_COMObject>>);
typedef _GetHapticsControllerD = int Function(
    Pointer<_COMObject>, Pointer<Pointer<_COMObject>>);

// ISimpleHapticsController::get_SupportedFeedback  (vtable index 11)
typedef _GetSupportedFeedbackN = Int32 Function(
    Pointer<_COMObject>, Pointer<Pointer<_COMObject>>);
typedef _GetSupportedFeedbackD = int Function(
    Pointer<_COMObject>, Pointer<Pointer<_COMObject>>);

// IVectorView<SimpleHapticsControllerFeedback>::GetAt  (vtable index 6)
typedef _VectorGetAtN = Int32 Function(
    Pointer<_COMObject>, Uint32, Pointer<Pointer<_COMObject>>);
typedef _VectorGetAtD = int Function(
    Pointer<_COMObject>, int, Pointer<Pointer<_COMObject>>);

// IVectorView<…>::get_Size  (vtable index 7)
typedef _VectorGetSizeN = Int32 Function(Pointer<_COMObject>, Pointer<Uint32>);
typedef _VectorGetSizeD = int Function(Pointer<_COMObject>, Pointer<Uint32>);

// ISimpleHapticsControllerFeedback::get_Waveform  (vtable index 6)
typedef _GetWaveformN = Int32 Function(Pointer<_COMObject>, Pointer<Uint16>);
typedef _GetWaveformD = int Function(Pointer<_COMObject>, Pointer<Uint16>);

// ISimpleHapticsController::SendHapticFeedbackWithIntensity  (vtable index 14)
typedef _SendFeedbackWithIntensityN = Int32 Function(
    Pointer<_COMObject>, Pointer<_COMObject>, Double);
typedef _SendFeedbackWithIntensityD = int Function(
    Pointer<_COMObject>, Pointer<_COMObject>, double);

// ISimpleHapticsController::StopFeedback  (vtable index 15)
typedef _StopFeedbackN = Int32 Function(Pointer<_COMObject>);
typedef _StopFeedbackD = int Function(Pointer<_COMObject>);

// ═══════════════════════════════════════════════════════════════════════════
// Vtable dispatch helpers – one per concrete method signature
// ═══════════════════════════════════════════════════════════════════════════
//
// dart:ffi's asFunction<F>() requires F to be a concrete type known at
// compile time, so a generic helper is not viable.  Each helper below
// binds to the correct vtable slot and returns the Dart-callable function.

_QueryInterfaceD _queryInterface(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[0]
        .cast<NativeFunction<_QueryInterfaceN>>()
        .asFunction<_QueryInterfaceD>();

_ReleaseD _release(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[2]
        .cast<NativeFunction<_ReleaseN>>()
        .asFunction<_ReleaseD>();

_GetFromPointerIdD _getFromPointerId(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[6]
        .cast<NativeFunction<_GetFromPointerIdN>>()
        .asFunction<_GetFromPointerIdD>();

_GetHapticsControllerD _getHapticsControllerFn(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[6]
        .cast<NativeFunction<_GetHapticsControllerN>>()
        .asFunction<_GetHapticsControllerD>();

_GetSupportedFeedbackD _getSupportedFeedback(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[11]
        .cast<NativeFunction<_GetSupportedFeedbackN>>()
        .asFunction<_GetSupportedFeedbackD>();

_VectorGetAtD _vectorGetAt(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[6]
        .cast<NativeFunction<_VectorGetAtN>>()
        .asFunction<_VectorGetAtD>();

_VectorGetSizeD _vectorGetSize(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[7]
        .cast<NativeFunction<_VectorGetSizeN>>()
        .asFunction<_VectorGetSizeD>();

_GetWaveformD _getWaveform(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[6]
        .cast<NativeFunction<_GetWaveformN>>()
        .asFunction<_GetWaveformD>();

_SendFeedbackWithIntensityD _sendFeedbackWithIntensity(
        Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[14]
        .cast<NativeFunction<_SendFeedbackWithIntensityN>>()
        .asFunction<_SendFeedbackWithIntensityD>();

_StopFeedbackD _stopFeedback(Pointer<_COMObject> obj) =>
    obj.ref.lpVtbl[15]
        .cast<NativeFunction<_StopFeedbackN>>()
        .asFunction<_StopFeedbackD>();

// ═══════════════════════════════════════════════════════════════════════════
// GUID construction helpers
// ═══════════════════════════════════════════════════════════════════════════

/// Fills [guid] with the supplied GUID components.
void _setGuid(
    Pointer<_GUID> guid, int d1, int d2, int d3, List<int> d4) {
  guid.ref.data1 = d1;
  guid.ref.data2 = d2;
  guid.ref.data3 = d3;
  for (var i = 0; i < 8; i++) {
    guid.ref.data4[i] = d4[i];
  }
}

/// IID for `Windows.UI.Input.IPenDeviceStatics`
/// {0BBD9FA0-3BF9-4615-84A0-7C67AE5B3AB1}
Pointer<_GUID> _iidPenDeviceStatics(Arena arena) {
  final g = arena<_GUID>();
  _setGuid(g, 0x0BBD9FA0, 0x3BF9, 0x4615,
      [0x84, 0xA0, 0x7C, 0x67, 0xAE, 0x5B, 0x3A, 0xB1]);
  return g;
}

/// IID for `Windows.UI.Input.IPenDevice2`
/// {1DDA8D2A-D1B5-5C60-B42D-26C5C91F4CB5}
Pointer<_GUID> _iidPenDevice2(Arena arena) {
  final g = arena<_GUID>();
  _setGuid(g, 0x1DDA8D2A, 0xD1B5, 0x5C60,
      [0xB4, 0x2D, 0x26, 0xC5, 0xC9, 0x1F, 0x4C, 0xB5]);
  return g;
}

// ═══════════════════════════════════════════════════════════════════════════
// WindowsHapticsController
// ═══════════════════════════════════════════════════════════════════════════

/// Windows implementation of [HapticsController] that drives the
/// `SimpleHapticsController` WinRT API via `dart:ffi`.
///
/// The class is intentionally lazy: it creates WinRT objects on the first
/// call to [startDrawingFeedback] and caches them for subsequent strokes.
/// If the pen does not expose a `SimpleHapticsController` (e.g. a non-haptic
/// stylus or a plain mouse pointer), the methods silently become no-ops.
class WindowsHapticsController implements HapticsController {
  // ── combase.dll exports ──────────────────────────────────────────────────
  late final _WindowsCreateStringD _windowsCreateString;
  late final _WindowsDeleteStringD _windowsDeleteString;
  late final _RoInitializeD _roInitialize;
  late final _RoGetActivationFactoryD _roGetActivationFactory;

  bool _isInitialized = false;

  /// Pointer to the cached `ISimpleHapticsController` COM interface.
  /// `null` when the pen has no haptics or has not been seen yet.
  Pointer<_COMObject>? _hapticsController;

  /// The cached `ISimpleHapticsControllerFeedback` for the InkContinuous
  /// (or BuzzContinuous fallback) waveform.
  Pointer<_COMObject>? _inkFeedback;

  // ── HapticsController ────────────────────────────────────────────────────

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final combase = DynamicLibrary.open('combase.dll');

      _windowsCreateString =
          combase.lookupFunction<_WindowsCreateStringN, _WindowsCreateStringD>(
              'WindowsCreateString');
      _windowsDeleteString =
          combase.lookupFunction<_WindowsDeleteStringN, _WindowsDeleteStringD>(
              'WindowsDeleteString');
      _roInitialize =
          combase.lookupFunction<_RoInitializeN, _RoInitializeD>(
              'RoInitialize');
      _roGetActivationFactory = combase.lookupFunction<
          _RoGetActivationFactoryN,
          _RoGetActivationFactoryD>('RoGetActivationFactory');

      // RO_INIT_MULTITHREADED = 1
      // Ignore RPC_E_CHANGED_MODE (0x80010106) – already initialised.
      final hr = _roInitialize(1);
      if (!_succeeded(hr) && hr != -2147417850 /* RPC_E_CHANGED_MODE */) {
        return; // WinRT unavailable – stay as no-op.
      }

      _isInitialized = true;
    } catch (_) {
      // combase.dll missing or symbol not found; stay as no-op.
    }
  }

  @override
  void startDrawingFeedback({required int pointerId, double intensity = 1.0}) {
    if (!_isInitialized) return;

    // Lazily resolve the haptics controller for the current pointer, or reuse
    // the cached one from a previous stroke.
    _hapticsController ??= _getHapticsController(pointerId);
    final controller = _hapticsController;
    if (controller == null) return;

    _inkFeedback ??= _findFeedback(controller);
    final feedback = _inkFeedback;
    if (feedback == null) return;

    // ISimpleHapticsController::SendHapticFeedbackWithIntensity (vtable 14)
    _sendFeedbackWithIntensity(controller)(
        controller, feedback, intensity.clamp(0.0, 1.0));
  }

  @override
  void updateIntensity(double intensity) {
    // Re-send with the new intensity; the waveform restarts seamlessly.
    final controller = _hapticsController;
    final feedback = _inkFeedback;
    if (controller == null || feedback == null) return;

    _sendFeedbackWithIntensity(controller)(
        controller, feedback, intensity.clamp(0.0, 1.0));
  }

  @override
  void stopFeedback() {
    final controller = _hapticsController;
    if (controller == null) return;
    // ISimpleHapticsController::StopFeedback (vtable 15)
    _stopFeedback(controller)(controller);
  }

  @override
  void dispose() {
    _releaseController();
    _isInitialized = false;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Walks the WinRT COM chain to reach `ISimpleHapticsController` for the
  /// given Flutter [pointerId].
  ///
  /// Returns `null` when the device does not support haptics or any COM call
  /// fails.
  Pointer<_COMObject>? _getHapticsController(int pointerId) {
    return using((arena) {
      // 1. Create HSTRING for the runtime class name.
      final classNamePtr = 'Windows.UI.Input.PenDevice'.toNativeUtf16(
        allocator: arena,
      );
      final hstringPtr = arena<IntPtr>();
      final hsHr = _windowsCreateString(classNamePtr, 26, hstringPtr);
      if (!_succeeded(hsHr)) return null;
      final hstring = hstringPtr.value;

      // 2. RoGetActivationFactory → IPenDeviceStatics.
      final factoryPtr = arena<Pointer<_COMObject>>();
      final iidStatics = _iidPenDeviceStatics(arena);
      final factHr =
          _roGetActivationFactory(hstring, iidStatics, factoryPtr);
      _windowsDeleteString(hstring);
      if (!_succeeded(factHr) || factoryPtr.value.address == 0) return null;
      final factory = factoryPtr.value;

      // 3. IPenDeviceStatics::GetFromPointerId (vtable 6).
      final penDevPtr = arena<Pointer<_COMObject>>();
      final penHr = _getFromPointerId(factory)(factory, pointerId, penDevPtr);
      _release(factory)(factory);
      if (!_succeeded(penHr) || penDevPtr.value.address == 0) return null;
      final penDevice = penDevPtr.value;

      // 4. QueryInterface for IPenDevice2 (has SimpleHapticsController).
      final iidPenDev2 = _iidPenDevice2(arena);
      final penDev2Ptr = arena<Pointer<_COMObject>>();
      final qiHr =
          _queryInterface(penDevice)(penDevice, iidPenDev2, penDev2Ptr);
      _release(penDevice)(penDevice);
      if (!_succeeded(qiHr) || penDev2Ptr.value.address == 0) return null;
      final penDevice2 = penDev2Ptr.value;

      // 5. IPenDevice2::get_SimpleHapticsController (vtable 6).
      final hcPtr = arena<Pointer<_COMObject>>();
      final hcHr = _getHapticsControllerFn(penDevice2)(penDevice2, hcPtr);
      _release(penDevice2)(penDevice2);
      if (!_succeeded(hcHr) || hcPtr.value.address == 0) return null;

      // The haptics controller pointer is kept alive beyond this arena scope,
      // so we must NOT free it here; the caller is responsible.
      return hcPtr.value;
    });
  }

  /// Enumerates `ISimpleHapticsController::SupportedFeedback` and returns the
  /// first feedback object whose waveform matches [_kWaveformInkContinuous],
  /// falling back to [_kWaveformBuzzContinuous], or the first available entry.
  ///
  /// Returns `null` when the feedback list is empty or any COM call fails.
  Pointer<_COMObject>? _findFeedback(Pointer<_COMObject> controller) {
    return using((arena) {
      // ISimpleHapticsController::get_SupportedFeedback (vtable 11).
      final vecPtr = arena<Pointer<_COMObject>>();
      final hr = _getSupportedFeedback(controller)(controller, vecPtr);
      if (!_succeeded(hr) || vecPtr.value.address == 0) return null;
      final vector = vecPtr.value;

      // IVectorView::get_Size (vtable 7).
      final sizePtr = arena<Uint32>();
      _vectorGetSize(vector)(vector, sizePtr);
      final count = sizePtr.value;
      if (count == 0) {
        _release(vector)(vector);
        return null;
      }

      Pointer<_COMObject>? best; // InkContinuous match
      Pointer<_COMObject>? buzz; // BuzzContinuous match
      Pointer<_COMObject>? first; // first entry, any waveform

      for (var i = 0; i < count; i++) {
        // IVectorView::GetAt (vtable 6).
        final itemPtr = arena<Pointer<_COMObject>>();
        final getHr = _vectorGetAt(vector)(vector, i, itemPtr);
        if (!_succeeded(getHr) || itemPtr.value.address == 0) continue;
        final item = itemPtr.value;

        // ISimpleHapticsControllerFeedback::get_Waveform (vtable 6).
        final wavePtr = arena<Uint16>();
        _getWaveform(item)(item, wavePtr);
        final waveform = wavePtr.value;

        if (waveform == _kWaveformInkContinuous) {
          best = item;
          break; // Optimal waveform found; remaining items not fetched.
        } else if (waveform == _kWaveformBuzzContinuous) {
          buzz ??= item;
          if (buzz != item) _release(item)(item); // Release duplicate.
        } else {
          first ??= item;
          if (first != item) _release(item)(item); // Release duplicate.
        }
      }

      _release(vector)(vector);

      // Release the runner-up candidates that will not be used.
      final chosen = best ?? buzz ?? first;
      if (best != null && chosen != best) _release(best)(best);
      if (buzz != null && chosen != buzz) _release(buzz)(buzz);
      if (first != null && chosen != first) _release(first)(first);

      return chosen;
    });
  }

  void _releaseController() {
    final feedback = _inkFeedback;
    if (feedback != null) {
      _release(feedback)(feedback);
      _inkFeedback = null;
    }
    final controller = _hapticsController;
    if (controller != null) {
      _release(controller)(controller);
      _hapticsController = null;
    }
  }
}
