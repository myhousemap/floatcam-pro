package com.floatcam.pro.ui.viewmodels

import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.floatcam.pro.data.model.*
import com.floatcam.pro.data.repository.SettingsRepository
import com.floatcam.pro.service.FloatingCameraService
import com.floatcam.pro.utils.PermissionUtils
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class PermissionState(
    val camera: Boolean = false,
    val microphone: Boolean = false,
    val notification: Boolean = false,
    val overlay: Boolean = false
) {
    val allRequiredGranted: Boolean
        get() = camera && overlay && notification
}

class MainViewModel(application: Application) : AndroidViewModel(application) {

    private val settingsRepository = SettingsRepository(application)

    val settings: StateFlow<CameraSettings> = settingsRepository.settingsFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), CameraSettings())

    val isOnboardingCompleted: StateFlow<Boolean> = settingsRepository.isOnboardingCompleted
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val isServiceRunning: StateFlow<Boolean> = FloatingCameraService.isServiceRunning

    val isRecordingActive: StateFlow<Boolean> = FloatingCameraService.isRecordingActive

    private val _permissionState = MutableStateFlow(PermissionState())
    val permissionState: StateFlow<PermissionState> = _permissionState.asStateFlow()

    init {
        checkPermissions()
    }

    fun checkPermissions() {
        val app = getApplication<Application>()
        _permissionState.value = PermissionState(
            camera = PermissionUtils.hasCameraPermission(app),
            microphone = PermissionUtils.hasRecordAudioPermission(app),
            notification = PermissionUtils.hasNotificationPermission(app),
            overlay = PermissionUtils.hasOverlayPermission(app)
        )
    }

    fun completeOnboarding() {
        viewModelScope.launch {
            settingsRepository.setOnboardingCompleted(true)
        }
    }

    fun toggleFloatingCamera(context: Context) {
        if (isServiceRunning.value) {
            val stopIntent = Intent(context, FloatingCameraService::class.java).apply {
                action = FloatingCameraService.ACTION_STOP_SERVICE
            }
            context.startService(stopIntent)
        } else {
            val startIntent = Intent(context, FloatingCameraService::class.java).apply {
                action = FloatingCameraService.ACTION_START_SERVICE
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(startIntent)
            } else {
                context.startService(startIntent)
            }
        }
    }

    fun updateShape(shape: ShapePreset) {
        viewModelScope.launch {
            settingsRepository.updateShape(shape)
        }
    }

    fun updateLens(lens: CameraLens) {
        viewModelScope.launch {
            settingsRepository.updateLens(lens)
        }
    }

    fun updateAudio(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.updateAudioEnabled(enabled)
        }
    }

    fun updateResolution(resolution: VideoResolution) {
        viewModelScope.launch {
            settingsRepository.updateResolution(resolution)
        }
    }
}
