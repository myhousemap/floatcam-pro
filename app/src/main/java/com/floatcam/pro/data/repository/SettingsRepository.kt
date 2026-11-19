package com.floatcam.pro.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import com.floatcam.pro.data.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "floatcam_settings")

class SettingsRepository(private val context: Context) {

    private object PreferencesKeys {
        val KEY_SHAPE = stringPreferencesKey("shape")
        val KEY_LENS = stringPreferencesKey("lens")
        val KEY_RESOLUTION = stringPreferencesKey("resolution")
        val KEY_FPS = intPreferencesKey("fps")
        val KEY_AUDIO_ENABLED = booleanPreferencesKey("audio_enabled")
        val KEY_MIRROR_FRONT = booleanPreferencesKey("mirror_front")
        val KEY_OPACITY = floatPreferencesKey("opacity")
        val KEY_BORDER_COLOR = longPreferencesKey("border_color")
        val KEY_BORDER_WIDTH = intPreferencesKey("border_width")
        val KEY_KEEP_SCREEN_ON = booleanPreferencesKey("keep_screen_on")
        val KEY_AUTO_HIDE_SEC = intPreferencesKey("auto_hide_sec")
        val KEY_ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")
    }

    val settingsFlow: Flow<CameraSettings> = context.dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }
        .map { prefs ->
            val shapeStr = prefs[PreferencesKeys.KEY_SHAPE] ?: ShapePreset.CIRCLE.name
            val lensStr = prefs[PreferencesKeys.KEY_LENS] ?: CameraLens.FRONT.name
            val resStr = prefs[PreferencesKeys.KEY_RESOLUTION] ?: VideoResolution.FHD_1080P.name
            val fpsVal = prefs[PreferencesKeys.KEY_FPS] ?: 30

            CameraSettings(
                shape = runCatching { ShapePreset.valueOf(shapeStr) }.getOrDefault(ShapePreset.CIRCLE),
                lens = runCatching { CameraLens.valueOf(lensStr) }.getOrDefault(CameraLens.FRONT),
                resolution = runCatching { VideoResolution.valueOf(resStr) }.getOrDefault(VideoResolution.FHD_1080P),
                fps = if (fpsVal == 60) FrameRate.FPS_60 else FrameRate.FPS_30,
                audioEnabled = prefs[PreferencesKeys.KEY_AUDIO_ENABLED] ?: true,
                mirrorFrontCamera = prefs[PreferencesKeys.KEY_MIRROR_FRONT] ?: true,
                opacity = prefs[PreferencesKeys.KEY_OPACITY] ?: 1.0f,
                borderColor = prefs[PreferencesKeys.KEY_BORDER_COLOR] ?: 0xFF4F8CFF,
                borderWidthDp = prefs[PreferencesKeys.KEY_BORDER_WIDTH] ?: 2,
                keepScreenOn = prefs[PreferencesKeys.KEY_KEEP_SCREEN_ON] ?: true,
                autoHideHudTimeoutSec = prefs[PreferencesKeys.KEY_AUTO_HIDE_SEC] ?: 3
            )
        }

    val isOnboardingCompleted: Flow<Boolean> = context.dataStore.data
        .catch { emit(emptyPreferences()) }
        .map { prefs -> prefs[PreferencesKeys.KEY_ONBOARDING_COMPLETED] ?: false }

    suspend fun setOnboardingCompleted(completed: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_ONBOARDING_COMPLETED] = completed
        }
    }

    suspend fun updateShape(shape: ShapePreset) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_SHAPE] = shape.name
        }
    }

    suspend fun updateLens(lens: CameraLens) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_LENS] = lens.name
        }
    }

    suspend fun updateResolution(resolution: VideoResolution) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_RESOLUTION] = resolution.name
        }
    }

    suspend fun updateFps(fps: FrameRate) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_FPS] = fps.fps
        }
    }

    suspend fun updateAudioEnabled(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_AUDIO_ENABLED] = enabled
        }
    }

    suspend fun updateMirrorFront(mirror: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_MIRROR_FRONT] = mirror
        }
    }

    suspend fun updateOpacity(opacity: Float) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_OPACITY] = opacity
        }
    }

    suspend fun updateBorderColor(color: Long) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_BORDER_COLOR] = color
        }
    }

    suspend fun updateBorderWidth(widthDp: Int) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_BORDER_WIDTH] = widthDp
        }
    }

    suspend fun updateKeepScreenOn(keepOn: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_KEEP_SCREEN_ON] = keepOn
        }
    }

    suspend fun updateAutoHideHudTimeout(seconds: Int) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.KEY_AUTO_HIDE_SEC] = seconds
        }
    }
}
