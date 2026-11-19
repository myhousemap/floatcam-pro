package com.floatcam.pro.ui.screens

import android.Manifest
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.floatcam.pro.ui.theme.*
import com.floatcam.pro.ui.viewmodels.MainViewModel
import com.floatcam.pro.ui.viewmodels.PermissionState
import com.floatcam.pro.utils.PermissionUtils

@Composable
fun OnboardingScreen(
    viewModel: MainViewModel,
    permissionState: PermissionState,
    onComplete: () -> Unit
) {
    val context = LocalContext.current

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) {
        viewModel.checkPermissions()
    }

    val micPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) {
        viewModel.checkPermissions()
    }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) {
        viewModel.checkPermissions()
    }

    val overlayLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        viewModel.checkPermissions()
    }

    LaunchedEffect(Unit) {
        viewModel.checkPermissions()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ObsidianBackground)
            .statusBarsPadding()
            .navigationBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(24.dp))

        // App Icon Badge
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(ObsidianSurface)
                .border(1.dp, ObsidianBorder, RoundedCornerShape(20.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.CameraAlt,
                contentDescription = null,
                tint = PrimaryBlue,
                modifier = Modifier.size(36.dp)
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Welcome to FloatCam Pro",
            style = MaterialTheme.typography.headlineLarge,
            color = TextPrimary
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "To enable professional floating camera overlay, please grant the following permissions.",
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary,
            modifier = Modifier.padding(horizontal = 16.dp)
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Step 1: Camera
        PermissionCard(
            title = "Camera Access",
            description = "Required to preview and capture video/photos in overlay.",
            icon = Icons.Default.CameraAlt,
            isGranted = permissionState.camera,
            isRequired = true,
            onGrantClick = {
                cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
            }
        )

        Spacer(modifier = Modifier.height(14.dp))

        // Step 2: Overlay
        PermissionCard(
            title = "Display Over Other Apps",
            description = "Required to float camera window over games and apps.",
            icon = Icons.Default.Layers,
            isGranted = permissionState.overlay,
            isRequired = true,
            onGrantClick = {
                overlayLauncher.launch(PermissionUtils.getOverlayPermissionIntent(context))
            }
        )

        Spacer(modifier = Modifier.height(14.dp))

        // Step 3: Microphone
        PermissionCard(
            title = "Microphone Audio",
            description = "Records crystal-clear audio during video captures.",
            icon = Icons.Default.Mic,
            isGranted = permissionState.microphone,
            isRequired = false,
            onGrantClick = {
                micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        )

        Spacer(modifier = Modifier.height(14.dp))

        // Step 4: Notifications (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            PermissionCard(
                title = "Foreground Notification",
                description = "Keeps overlay service active and provides quick controls.",
                icon = Icons.Default.Notifications,
                isGranted = permissionState.notification,
                isRequired = true,
                onGrantClick = {
                    notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            )

            Spacer(modifier = Modifier.height(14.dp))
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Continue Button
        val canProceed = permissionState.allRequiredGranted
        Button(
            onClick = {
                if (canProceed) {
                    viewModel.completeOnboarding()
                    onComplete()
                }
            },
            enabled = canProceed,
            colors = ButtonDefaults.buttonColors(
                containerColor = PrimaryBlue,
                disabledContainerColor = ObsidianSurfaceVariant
            ),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp)
        ) {
            Text(
                text = if (canProceed) "Get Started with FloatCam Pro" else "Grant Required Permissions Above",
                style = MaterialTheme.typography.labelLarge,
                color = if (canProceed) Color.White else TextMuted
            )
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
private fun PermissionCard(
    title: String,
    description: String,
    icon: ImageVector,
    isGranted: Boolean,
    isRequired: Boolean,
    onGrantClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, ObsidianBorder, RoundedCornerShape(18.dp)),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = ObsidianSurface)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Icon
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(if (isGranted) SuccessGreen.copy(alpha = 0.15f) else ObsidianSurfaceVariant),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = if (isGranted) SuccessGreen else TextSecondary,
                    modifier = Modifier.size(22.dp)
                )
            }

            Spacer(modifier = Modifier.width(14.dp))

            // Text
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleMedium,
                        color = TextPrimary
                    )
                    if (isRequired) {
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Required",
                            style = MaterialTheme.typography.labelSmall,
                            color = RecordingRed,
                            fontSize = 10.sp
                        )
                    }
                }
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    fontSize = 12.sp
                )
            }

            Spacer(modifier = Modifier.width(10.dp))

            // Action
            if (isGranted) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(SuccessGreen),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = "Granted",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
            } else {
                OutlinedButton(
                    onClick = onGrantClick,
                    shape = RoundedCornerShape(12.dp),
                    border = ButtonDefaults.outlinedButtonBorder(enabled = true).copy(
                        brush = androidx.compose.ui.graphics.SolidColor(PrimaryBlue)
                    ),
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = "Allow",
                        style = MaterialTheme.typography.labelSmall,
                        color = PrimaryBlue,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}
