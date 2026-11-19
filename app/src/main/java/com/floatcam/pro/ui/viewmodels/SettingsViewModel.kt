package com.floatcam.pro.ui.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.floatcam.pro.data.model.*
import com.floatcam.pro.data.repository.SettingsRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class SettingsViewModel(application: Application) : AndroidViewModel(application) {

    private val settingsRepository = SettingsRepository(application)

    val settings: StateFlow<CameraSettings> = settingsRepository.settingsFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), CameraSettings())

    fun updateResolution(resolution: VideoResolution) {
        viewModelScope.launch { settingsRepository.updateResolution(resolution) }
    }

    fun updateFps(fps: FrameRate) {
        viewModelScope.launch { settingsRepository.updateFps(fps) }
    }

    fun updateAudioEnabled(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.updateAudioEnabled(enabled) }
    }

    fun updateMirrorFront(mirror: Boolean) {
        viewModelScope.launch { settingsRepository.updateMirrorFront(mirror) }
    }

    fun updateOpacity(opacity: Float) {
        viewModelScope.launch { settingsRepository.updateOpacity(opacity) }
    }

    fun updateBorderColor(color: Long) {
        viewModelScope.launch { settingsRepository.updateBorderColor(color) }
    }

    fun updateBorderWidth(widthDp: Int) {
        viewModelScope.launch { settingsRepository.updateBorderWidth(widthDp) }
    }

    fun updateKeepScreenOn(keepOn: Boolean) {
        viewModelScope.launch { settingsRepository.updateKeepScreenOn(keepOn) }
    }

    fun updateAutoHideHudTimeout(seconds: Int) {
        viewModelScope.launch { settingsRepository.updateAutoHideHudTimeout(seconds) }
    }
}
