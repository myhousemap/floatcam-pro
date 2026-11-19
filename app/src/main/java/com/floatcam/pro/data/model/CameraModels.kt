package com.floatcam.pro.data.model

import android.net.Uri

enum class ShapePreset(val title: String, val aspectRatioWidth: Int, val aspectRatioHeight: Int) {
    CIRCLE("Circle (Facecam)", 1, 1),
    SQUARE_1_1("Square (1:1)", 1, 1),
    PORTRAIT_9_16("Portrait (9:16)", 9, 16),
    LANDSCAPE_16_9("Landscape (16:9)", 16, 9)
}

enum class CameraLens(val label: String) {
    BACK("Rear Camera"),
    FRONT("Front Camera")
}

enum class VideoResolution(val label: String, val width: Int, val height: Int) {
    SD_480P("SD 480p", 720, 480),
    HD_720P("HD 720p", 1280, 720),
    FHD_1080P("FHD 1080p", 1920, 1080),
    UHD_4K("4K UHD", 3840, 2160)
}

enum class FrameRate(val fps: Int, val label: String) {
    FPS_30(30, "30 FPS"),
    FPS_60(60, "60 FPS")
}

data class CameraSettings(
    val shape: ShapePreset = ShapePreset.CIRCLE,
    val lens: CameraLens = CameraLens.FRONT,
    val resolution: VideoResolution = VideoResolution.FHD_1080P,
    val fps: FrameRate = FrameRate.FPS_30,
    val audioEnabled: Boolean = true,
    val mirrorFrontCamera: Boolean = true,
    val opacity: Float = 1.0f,
    val borderColor: Long = 0xFF4F8CFF,
    val borderWidthDp: Int = 2,
    val keepScreenOn: Boolean = true,
    val autoHideHudTimeoutSec: Int = 3
)

data class MediaItem(
    val id: Long,
    val uri: Uri,
    val name: String,
    val isVideo: Boolean,
    val durationMs: Long = 0L,
    val sizeBytes: Long = 0L,
    val dateAdded: Long = 0L,
    val width: Int = 0,
    val height: Int = 0
)
