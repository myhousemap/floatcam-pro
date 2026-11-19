package com.floatcam.pro.service

import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.floatcam.pro.MainActivity
import com.floatcam.pro.utils.PermissionUtils

class FloatCamTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()

        // Verify permissions
        if (!PermissionUtils.hasAllRequiredPermissions(this)) {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startActivityAndCollapse(
                    android.app.PendingIntent.getActivity(
                        this,
                        0,
                        intent,
                        android.app.PendingIntent.FLAG_IMMUTABLE
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
            return
        }

        if (FloatingCameraService.isServiceRunning.value) {
            val stopIntent = Intent(this, FloatingCameraService::class.java).apply {
                action = FloatingCameraService.ACTION_STOP_SERVICE
            }
            startService(stopIntent)
        } else {
            val startIntent = Intent(this, FloatingCameraService::class.java).apply {
                action = FloatingCameraService.ACTION_START_SERVICE
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(startIntent)
            } else {
                startService(startIntent)
            }
        }

        updateTileState()
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        val isRunning = FloatingCameraService.isServiceRunning.value
        tile.state = if (isRunning) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = if (isRunning) "FloatCam On" else "FloatCam Off"
        tile.updateTile()
    }
}
