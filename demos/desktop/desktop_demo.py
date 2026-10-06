"""Windows/Linux desktop demo using the native SDK + native MODNet adapter.
No model downloads at runtime. Supports photos, videos and an OpenCV webcam UI.
"""

import argparse
import ctypes as C
import json
import platform
import sys
import time
from contextlib import ExitStack
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT


def available(*paths):
    return next((path for path in paths if path.exists()), paths[0])


class Config(C.Structure):
    _fields_ = [
        ("struct_size", C.c_uint32),
        ("abi_version", C.c_uint32),
        ("backend", C.c_int),
        ("max_width", C.c_uint32),
        ("max_height", C.c_uint32),
    ]


class Options(C.Structure):
    _fields_ = [
        ("struct_size", C.c_uint32),
        ("beauty", C.c_float),
        ("whitening", C.c_float),
        ("sharpen", C.c_float),
        ("background", C.c_int),
        ("blur_radius", C.c_uint32),
        ("mask_smoothing", C.c_float),
        ("prop", C.c_uint32),
        ("headwear", C.c_uint32),
        ("jewelry", C.c_uint32),
        *[
            (name, C.c_float)
            for name in (
                "eye_enlarge",
                "face_slim",
                "blemish_removal",
                "lipstick",
                "blush",
                "nose_slim",
                "eyebrow_darkening",
                "cheekbone_reduce",
                "eye_spacing",
                "small_head",
            )
        ],
        ("lipstick_color", C.c_uint32),
        ("skin_tone", C.c_int),
        ("debug_landmarks", C.c_uint32),
        ("debug_face_mesh", C.c_uint32),
    ]


class Frame(C.Structure):
    _fields_ = [
        ("data", C.c_void_p),
        ("size_bytes", C.c_size_t),
        ("width", C.c_uint32),
        ("height", C.c_uint32),
        ("stride", C.c_uint32),
        ("format", C.c_int),
        ("time", C.c_int64),
    ]


class Output(C.Structure):
    _fields_ = [
        ("data", C.c_void_p),
        ("size_bytes", C.c_size_t),
        ("stride", C.c_uint32),
        ("format", C.c_int),
    ]


class Analysis(C.Structure):
    _fields_ = [
        ("mask", C.c_void_p),
        ("mw", C.c_uint32),
        ("mh", C.c_uint32),
        ("count", C.c_size_t),
        ("points", C.c_void_p),
        ("point_count", C.c_uint32),
        ("time", C.c_int64),
        ("person_mask_offset_x", C.c_float),
        ("person_mask_offset_y", C.c_float),
    ]


class MattingConfig(C.Structure):
    _fields_ = [
        ("struct_size", C.c_uint32),
        ("models", C.c_void_p),
        ("runtime", C.c_char_p),
        ("provider", C.c_int),
        ("size", C.c_uint32),
        ("threads", C.c_uint32),
        ("package_api_version", C.c_uint32),
    ]


class SDK:
    def __init__(self, path, backend=2):
        self.lib = C.CDLL(str(Path(path).resolve()))
        self.handle = C.c_void_p()
        self.timestamp = 0
        l = self.lib
        l.mvs_default_config.restype = Config
        l.mvs_default_options.restype = Options
        l.mvs_create.argtypes = [C.POINTER(Config), C.POINTER(C.c_void_p)]
        l.mvs_destroy.argtypes = [C.c_void_p]
        l.mvs_reset.argtypes = [C.c_void_p]
        l.mvs_backend.argtypes = [C.c_void_p]
        l.mvs_set_options.argtypes = [C.c_void_p, C.POINTER(Options)]
        l.mvs_process_with_analysis.argtypes = [
            C.c_void_p,
            C.POINTER(Frame),
            C.POINTER(Analysis),
            C.POINTER(Output),
        ]
        c = l.mvs_default_config()
        c.backend = backend
        c.max_width = c.max_height = 4096
        self.check(l.mvs_create(C.byref(c), C.byref(self.handle)))

    @staticmethod
    def check(status):
        if status:
            raise RuntimeError(f"Native SDK status {status}")

    def run(self, rgb, alpha, points, **kwargs):
        rgba = np.ascontiguousarray(cv2.cvtColor(rgb, cv2.COLOR_RGB2RGBA))
        h, w = rgb.shape[:2]
        alpha = np.ascontiguousarray(alpha, np.float32)
        points = np.ascontiguousarray(points, np.float32)
        o = self.lib.mvs_default_options()
        o.mask_smoothing = 0
        for key, value in kwargs.items():
            setattr(o, key, value)
        self.check(self.lib.mvs_set_options(self.handle, C.byref(o)))
        self.timestamp += 1
        f = Frame(rgba.ctypes.data, rgba.nbytes, w, h, w * 4, 0, self.timestamp)
        a = Analysis(
            alpha.ctypes.data,
            alpha.shape[1],
            alpha.shape[0],
            alpha.size,
            points.ctypes.data if len(points) else None,
            len(points),
            self.timestamp,
            0,
            0,
        )
        result = np.empty_like(rgba)
        dest = Output(result.ctypes.data, result.nbytes, w * 4, 0)
        t = time.perf_counter()
        self.check(
            self.lib.mvs_process_with_analysis(
                self.handle, C.byref(f), C.byref(a), C.byref(dest)
            )
        )
        return result[..., :3].copy(), (time.perf_counter() - t) * 1000

    def reset(self):
        self.lib.mvs_reset(self.handle)
        self.timestamp = 0

    def close(self):
        if self.handle:
            self.lib.mvs_destroy(self.handle)
            self.handle = None


class ModelView(C.Structure):
    _fields_ = [
        ("data", C.c_void_p),
        ("size", C.c_size_t),
        ("id", C.c_uint32),
        ("name", C.c_char * 32),
    ]


class Models:
    def __init__(self, sdk, path=None):
        self.lib = sdk.lib
        self.handle = C.c_void_p()
        self.lib.mvs_models_open.argtypes = [C.c_char_p, C.POINTER(C.c_void_p)]
        self.lib.mvs_models_get.argtypes = [
            C.c_void_p,
            C.c_uint32,
            C.POINTER(ModelView),
        ]
        self.lib.mvs_models_close.argtypes = [C.c_void_p]
        platform_name = "windows" if sys.platform == "win32" else "linux"
        path = (
            Path(path)
            if path
            else available(
                ROOT
                / "models/runtime"
                / platform_name
                / "mediavision.mvsmodels",
                PACKAGE / "models" / platform_name / "mediavision.mvsmodels",
            )
        )
        SDK.check(
            self.lib.mvs_models_open(
                str(path.resolve()).encode(), C.byref(self.handle)
            )
        )

    def bytes(self, id):
        view = ModelView()
        SDK.check(self.lib.mvs_models_get(self.handle, id, C.byref(view)))
        return C.string_at(view.data, view.size)

    def close(self):
        if self.handle:
            self.lib.mvs_models_close(self.handle)
            self.handle = None


class Matting:
    def __init__(self, sdk, runtime, provider="auto", size=512, models=None):
        self.lib = sdk.lib
        self.handle = C.c_void_p()
        self.models = models or Models(sdk)
        self.owns_models = models is None
        self.lib.mvs_matting_create.argtypes = [
            C.POINTER(MattingConfig),
            C.POINTER(C.c_void_p),
        ]
        self.lib.mvs_matting_process.argtypes = [
            C.c_void_p,
            C.POINTER(Frame),
            C.c_void_p,
            C.c_size_t,
        ]
        self.lib.mvs_matting_destroy.argtypes = [C.c_void_p]
        self.lib.mvs_matting_reset.argtypes = [C.c_void_p]
        self.lib.mvs_matting_last_error.argtypes = [C.c_void_p]
        self.lib.mvs_matting_last_error.restype = C.c_char_p
        providers = [1, 0] if sys.platform == "win32" else [2, 0]
        if provider != "auto":
            providers = [{"cpu": 0, "directml": 1, "cuda": 2}[provider]]
        for p in providers:
            c = MattingConfig(
                C.sizeof(MattingConfig),
                self.models.handle,
                str(Path(runtime).resolve()).encode(),
                p,
                size,
                8,
                1,
            )
            status = self.lib.mvs_matting_create(
                C.byref(c), C.byref(self.handle)
            )
            if status == 0:
                self.provider = p
                break
        else:
            if self.owns_models:
                self.models.close()
            raise RuntimeError(
                f"MODNet create failed: {status}; check model/runtime/provider"
            )

    def run(self, rgb, timestamp):
        rgba = np.ascontiguousarray(cv2.cvtColor(rgb, cv2.COLOR_RGB2RGBA))
        h, w = rgb.shape[:2]
        alpha = np.empty((h, w), np.float32)
        f = Frame(rgba.ctypes.data, rgba.nbytes, w, h, w * 4, 0, timestamp)
        t = time.perf_counter()
        status = self.lib.mvs_matting_process(
            self.handle, C.byref(f), alpha.ctypes.data, alpha.size
        )
        if status:
            raise RuntimeError(
                self.lib.mvs_matting_last_error(self.handle).decode()
            )
        if not np.isfinite(alpha).all():
            raise RuntimeError("Non-finite alpha")
        return alpha, (time.perf_counter() - t) * 1000

    def reset(self):
        self.lib.mvs_matting_reset(self.handle)

    def close(self):
        if self.handle:
            self.lib.mvs_matting_destroy(self.handle)
            self.handle = None
        if self.owns_models:
            self.models.close()


class Face:
    def __init__(self, video=False, models=None):
        v = mp.tasks.vision
        self.video = video
        self.models = models
        self._sdk = None
        self.task = None
        self.owns_models = models is None
        if self.models is None:
            linux_arch = (
                "aarch64"
                if platform.machine().lower() in {"aarch64", "arm64"}
                else "x86_64"
            )
            sdk_path = (
                available(
                    ROOT / "dist/package/windows/x64/shared/bin/mvs_sdk.dll",
                    PACKAGE / "sdk/windows/x64/shared/bin/mvs_sdk.dll",
                )
                if sys.platform == "win32"
                else available(
                    ROOT
                    / f"dist/package/linux/{linux_arch}/shared/lib/libmvs_sdk.so",
                    PACKAGE
                    / f"sdk/linux/{linux_arch}/shared/lib/libmvs_sdk.so",
                )
            )
            self._sdk = SDK(sdk_path, 1)
            try:
                self.models = Models(self._sdk)
            except Exception:
                self._sdk.close()
                raise
        try:
            self.task = v.FaceLandmarker.create_from_options(
                v.FaceLandmarkerOptions(
                    base_options=mp.tasks.BaseOptions(
                        model_asset_buffer=self.models.bytes(1)
                    ),
                    running_mode=(
                        v.RunningMode.VIDEO if video else v.RunningMode.IMAGE
                    ),
                    num_faces=1,
                )
            )
        except Exception:
            self.close()
            raise

    def run(self, rgb, timestamp):
        # Face detection has its own resolution budget. Matting still receives
        # the complete HD image and the native shader retains HD colour/detail.
        h, w = rgb.shape[:2]
        image = cv2.resize(
            rgb,
            (
                max(1, int(w * min(1, 768 / max(h, w)))),
                max(1, int(h * min(1, 768 / max(h, w)))),
            ),
        )
        t = time.perf_counter()
        frame = mp.Image(
            image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(image)
        )
        result = (
            self.task.detect_for_video(frame, timestamp)
            if self.video
            else self.task.detect(frame)
        )
        points = (
            np.asarray(
                [[p.x, p.y, p.z] for p in result.face_landmarks[0]], np.float32
            )
            if result.face_landmarks
            else np.empty((0, 3), np.float32)
        )
        return points, (time.perf_counter() - t) * 1000

    def close(self):
        if self.task is not None:
            self.task.close()
            self.task = None
        if self.owns_models:
            self.models.close()
            if self._sdk is not None:
                self._sdk.close()


def fit(rgb, maximum):
    h, w = rgb.shape[:2]
    scale = min(1, maximum / max(h, w))
    return (
        cv2.resize(
            rgb,
            (round(w * scale), round(h * scale)),
            interpolation=cv2.INTER_AREA,
        )
        if scale < 1
        else rgb
    )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", required=True, help="photo/video or camera:0")
    p.add_argument("--output", type=Path)
    linux_arm = platform.machine().lower() in {"aarch64", "arm64"}
    sdk_relative = (
        "windows/x64/shared/bin/mvs_sdk.dll"
        if sys.platform == "win32"
        else (
            "linux/aarch64/shared/lib/libmvs_sdk.so"
            if linux_arm
            else "linux/x86_64/shared/lib/libmvs_sdk.so"
        )
    )
    runtime_relative = (
        "windows-x64/onnxruntime.dll"
        if sys.platform == "win32"
        else (
            "linux-aarch64/libonnxruntime.so"
            if linux_arm
            else "linux-x64/libonnxruntime.so"
        )
    )
    p.add_argument(
        "--sdk",
        type=Path,
        default=available(
            ROOT / "dist/package" / sdk_relative, PACKAGE / "sdk" / sdk_relative
        ),
    )
    p.add_argument(
        "--runtime",
        type=Path,
        default=available(
            ROOT / "dist/package/desktop-runtime" / runtime_relative,
            PACKAGE / "dependencies/desktop-runtime" / runtime_relative,
        ),
    )
    p.add_argument(
        "--provider",
        choices=["auto", "cpu", "directml", "cuda"],
        default="auto",
    )
    p.add_argument("--backend", choices=["cpu", "vulkan"], default="vulkan")
    p.add_argument("--maximum", type=int, default=1920)
    p.add_argument("--model-size", type=int, default=512)
    p.add_argument(
        "--background",
        choices=["original", "blur", "replace", "mask"],
        default="blur",
    )
    for flag, default in [
        ("beauty", 0.6),
        ("blemish", 0.6),
        ("small-head", 0),
        ("lipstick", 0),
    ]:
        p.add_argument("--" + flag, type=float, default=default)
    p.add_argument("--models", type=Path, help="Single encrypted model package")
    a = p.parse_args()
    is_photo = Path(a.input).suffix.lower() in {
        ".jpg",
        ".jpeg",
        ".png",
        ".webp",
        ".bmp",
    }
    times = []
    opts = dict(
        background={"original": 0, "blur": 1, "replace": 2, "mask": 3}[
            a.background
        ],
        beauty=a.beauty,
        blemish_removal=a.blemish,
        small_head=a.small_head,
        lipstick=a.lipstick,
    )
    camera = a.input.startswith("camera:")
    cap = None
    writer = None
    resources = ExitStack()
    try:
        sdk = SDK(a.sdk, 1 if a.backend == "cpu" else 2)
        resources.callback(sdk.close)
        models = Models(sdk, a.models)
        resources.callback(models.close)
        mat = Matting(sdk, a.runtime, a.provider, a.model_size, models)
        resources.callback(mat.close)
        face = Face(not is_photo, models)
        resources.callback(face.close)
        if camera:
            cv2.namedWindow("MediaVision Desktop")
            for name, value in [
                ("beauty", a.beauty),
                ("blemish", a.blemish),
                ("small_head", a.small_head),
            ]:
                cv2.createTrackbar(
                    name,
                    "MediaVision Desktop",
                    round(value * 100),
                    100,
                    lambda _: None,
                )
        cap = (
            None
            if is_photo
            else cv2.VideoCapture(
                int(a.input.split(":")[1]) if camera else a.input
            )
        )
        if cap is not None and not cap.isOpened():
            raise RuntimeError(f"Cannot open input: {a.input}")
        rotation = 0
        if cap and not camera:
            cap.set(cv2.CAP_PROP_ORIENTATION_AUTO, 0)
            rotation = round(cap.get(cv2.CAP_PROP_ORIENTATION_META)) % 360
        fps = max(1, cap.get(cv2.CAP_PROP_FPS)) if cap else 1
        index = 0
        while True:
            if is_photo:
                if index:
                    break
                bgr = cv2.imdecode(
                    np.fromfile(a.input, np.uint8), cv2.IMREAD_COLOR
                )
                ok = bgr is not None
            else:
                ok, bgr = cap.read()
            if not ok:
                if index == 0:
                    raise RuntimeError(f"Cannot decode input: {a.input}")
                break
            if rotation:
                bgr = cv2.rotate(
                    bgr,
                    {
                        90: cv2.ROTATE_90_CLOCKWISE,
                        180: cv2.ROTATE_180,
                        270: cv2.ROTATE_90_COUNTERCLOCKWISE,
                    }[rotation],
                )
            rgb = fit(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB), a.maximum)
            timestamp = round(index * 1000 / fps) + 1
            alpha, mt = mat.run(rgb, timestamp)
            points, ft = face.run(rgb, timestamp)
            if camera:
                for key in ["beauty", "small_head"]:
                    opts[key] = (
                        cv2.getTrackbarPos(key, "MediaVision Desktop") / 100
                    )
                opts["blemish_removal"] = (
                    cv2.getTrackbarPos("blemish", "MediaVision Desktop") / 100
                )
            result, rt = sdk.run(rgb, alpha, points, **opts)
            times.append(dict(matting_ms=mt, face_ms=ft, render_ms=rt))
            index += 1
            if a.output:
                a.output.parent.mkdir(parents=True, exist_ok=True)
                if is_photo:
                    cv2.imencode(
                        a.output.suffix, cv2.cvtColor(result, cv2.COLOR_RGB2BGR)
                    )[1].tofile(a.output)
                else:
                    if writer is None:
                        writer = cv2.VideoWriter(
                            str(a.output),
                            cv2.VideoWriter_fourcc(*"mp4v"),
                            fps,
                            (result.shape[1], result.shape[0]),
                        )
                        if not writer.isOpened():
                            raise RuntimeError(
                                f"Cannot write video: {a.output}"
                            )
                    writer.write(cv2.cvtColor(result, cv2.COLOR_RGB2BGR))
            if camera:
                cv2.imshow(
                    "MediaVision Desktop",
                    cv2.cvtColor(result, cv2.COLOR_RGB2BGR),
                )
                if cv2.waitKey(1) & 255 == 27:
                    break
        print(
            json.dumps(
                dict(
                    frames=index,
                    provider=mat.provider,
                    backend=sdk.lib.mvs_backend(sdk.handle),
                    median_ms={
                        k: float(np.median([x[k] for x in times[2:] or times]))
                        for k in ["matting_ms", "face_ms", "render_ms"]
                    },
                ),
                indent=2,
            )
        )
    finally:
        if cap:
            cap.release()
        if writer:
            writer.release()
        cv2.destroyAllWindows()
        resources.close()


if __name__ == "__main__":
    main()
