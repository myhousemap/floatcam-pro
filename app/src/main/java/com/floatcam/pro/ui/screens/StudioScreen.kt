package com.floatcam.pro.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.floatcam.pro.data.model.*
import com.floatcam.pro.ui.theme.*
import com.floatcam.pro.ui.viewmodels.MainViewModel

@Composable
fun StudioScreen(viewModel: MainViewModel) {
    val context = LocalContext.current
    val settings by viewModel.settings.collectAsState()
    val isRunning by viewModel.isServiceRunning.collectAsState()
    val isRecording by viewModel.isRecordingActive.collectAsState()

    // Pulsing animation for active status
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.85f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ObsidianBackground)
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Top App Bar / Title
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(
                    text = "FloatCam Pro",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextPrimary
                )
                Text(
                    text = "Studio Control Center",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary
                )
            }

            // Status Pill
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = if (isRunning) SuccessGreen.copy(alpha = 0.15f) else ObsidianSurfaceVariant,
                border = androidx.compose.foundation.BorderStroke(
                    1.dp,
                    if (isRunning) SuccessGreen.copy(alpha = 0.5f) else ObsidianBorder
                )
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (isRunning) SuccessGreen else TextMuted)
                            .let {
                                if (isRunning) it.then(Modifier.alpha(pulseScale)) else it
                            }
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (isRunning) (if (isRecording) "RECORDING" else "OVERLAY ACTIVE") else "STANDBY",
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isRunning) SuccessGreen else TextMuted,
                        fontWeight = FontWeight.Bold,
                        fontSize = 10.sp
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Live Visual Mockup Preview Card
        StudioMockupCard(
            settings = settings,
            isRunning = isRunning,
            isRecording = isRecording
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Primary Launch / Stop Button
        val buttonColor by animateColorAsState(
            targetValue = if (isRunning) RecordingRed else PrimaryBlue,
            label = "btnColor"
        )

        Button(
            onClick = {
                viewModel.toggleFloatingCamera(context)
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(58.dp),
            shape = RoundedCornerShape(18.dp),
            colors = ButtonDefaults.buttonColors(containerColor = buttonColor),
            elevation = ButtonDefaults.buttonElevation(defaultElevation = 6.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(
                    imageVector = if (isRunning) Icons.Default.Close else Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = if (isRunning) "Stop Floating Camera" else "Launch Floating Camera",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // Quick Toggle Chips Section
        Text(
            text = "Quick Studio Presets",
            style = MaterialTheme.typography.titleMedium,
            color = TextPrimary,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(14.dp))

        // 1. Frame Shape Presets
        ChipCategorySection(title = "Frame Shape") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ShapePreset.values().forEach { shape ->
                    StudioChip(
                        selected = settings.shape == shape,
                        label = when (shape) {
                            ShapePreset.CIRCLE -> "Circle"
                            ShapePreset.SQUARE_1_1 -> "1:1 Square"
                            ShapePreset.PORTRAIT_9_16 -> "9:16 Story"
                            ShapePreset.LANDSCAPE_16_9 -> "16:9 Stream"
                        },
                        icon = when (shape) {
                            ShapePreset.CIRCLE -> Icons.Default.RadioButtonUnchecked
                            ShapePreset.SQUARE_1_1 -> Icons.Default.CropSquare
                            ShapePreset.PORTRAIT_9_16 -> Icons.Default.PhoneAndroid
                            ShapePreset.LANDSCAPE_16_9 -> Icons.Default.Tv
                        },
                        onClick = { viewModel.updateShape(shape) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 2. Camera Lens (Front / Rear)
        ChipCategorySection(title = "Camera Lens") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                CameraLens.values().forEach { lens ->
                    StudioChip(
                        selected = settings.lens == lens,
                        label = lens.label,
                        icon = if (lens == CameraLens.FRONT) Icons.Default.Face else Icons.Default.CameraRear,
                        onClick = { viewModel.updateLens(lens) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 3. Audio Recording Toggle
        ChipCategorySection(title = "Audio Capture") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                StudioChip(
                    selected = settings.audioEnabled,
                    label = "Mic On",
                    icon = Icons.Default.Mic,
                    onClick = { viewModel.updateAudio(true) },
                    modifier = Modifier.weight(1f)
                )
                StudioChip(
                    selected = !settings.audioEnabled,
                    label = "Muted",
                    icon = Icons.Default.MicOff,
                    onClick = { viewModel.updateAudio(false) },
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // 4. Video Resolution
        ChipCategorySection(title = "Capture Quality") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf(VideoResolution.HD_720P, VideoResolution.FHD_1080P, VideoResolution.UHD_4K).forEach { res ->
                    StudioChip(
                        selected = settings.resolution == res,
                        label = res.label,
                        icon = Icons.Default.HighQuality,
                        onClick = { viewModel.updateResolution(res) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun StudioMockupCard(
    settings: CameraSettings,
    isRunning: Boolean,
    isRecording: Boolean
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(260.dp)
            .border(1.dp, ObsidianBorder, RoundedCornerShape(24.dp)),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = ObsidianSurface)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            // Live Shape Mockup Box
            val shapeModifier = when (settings.shape) {
                ShapePreset.CIRCLE -> Modifier
                    .size(170.dp)
                    .clip(CircleShape)
                ShapePreset.SQUARE_1_1 -> Modifier
                    .size(170.dp)
                    .clip(RoundedCornerShape(24.dp))
                ShapePreset.PORTRAIT_9_16 -> Modifier
                    .width(120.dp)
                    .height(210.dp)
                    .clip(RoundedCornerShape(20.dp))
                ShapePreset.LANDSCAPE_16_9 -> Modifier
                    .width(220.dp)
                    .height(130.dp)
                    .clip(RoundedCornerShape(20.dp))
            }

            val borderColor = Color(settings.borderColor)
            val borderWidth = settings.borderWidthDp.dp

            Box(
                modifier = shapeModifier
                    .background(ObsidianSurfaceVariant.copy(alpha = settings.opacity))
                    .border(
                        width = borderWidth,
                        color = borderColor,
                        shape = when (settings.shape) {
                            ShapePreset.CIRCLE -> CircleShape
                            ShapePreset.SQUARE_1_1 -> RoundedCornerShape(24.dp)
                            ShapePreset.PORTRAIT_9_16, ShapePreset.LANDSCAPE_16_9 -> RoundedCornerShape(20.dp)
                        }
                    ),
                contentAlignment = Alignment.Center
            ) {
                // Mock camera lens representation
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(52.dp)
                            .clip(CircleShape)
                            .background(ObsidianBackground)
                            .border(1.dp, borderColor.copy(alpha = 0.5f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = if (settings.lens == CameraLens.FRONT) Icons.Default.Face else Icons.Default.CameraRear,
                            contentDescription = null,
                            tint = borderColor,
                            modifier = Modifier.size(28.dp)
                        )
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    Text(
                        text = settings.shape.title,
                        style = MaterialTheme.typography.labelSmall,
                        color = TextPrimary,
                        fontSize = 11.sp
                    )

                    Text(
                        text = "${settings.resolution.label} • ${settings.fps.label}",
                        style = MaterialTheme.typography.labelSmall,
                        color = TextSecondary,
                        fontSize = 9.sp
                    )
                }

                // Top corner badge if recording
                if (isRecording) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(8.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(RecordingRed)
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "REC",
                            color = Color.White,
                            fontSize = 8.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChipCategorySection(
    title: String,
    content: @Composable () -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall,
            color = TextSecondary,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium
        )
        Spacer(modifier = Modifier.height(8.dp))
        content()
    }
}

@Composable
private fun StudioChip(
    selected: Boolean,
    label: String,
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val bgColor by animateColorAsState(
        targetValue = if (selected) PrimaryBlue.copy(alpha = 0.2f) else ObsidianSurface,
        label = "chipBg"
    )
    val borderColor by animateColorAsState(
        targetValue = if (selected) PrimaryBlue else ObsidianBorder,
        label = "chipBorder"
    )
    val contentColor by animateColorAsState(
        targetValue = if (selected) PrimaryBlue else TextSecondary,
        label = "chipContent"
    )

    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .clickable { onClick() },
        shape = RoundedCornerShape(14.dp),
        color = bgColor,
        border = androidx.compose.foundation.BorderStroke(1.dp, borderColor)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = if (selected) TextPrimary else TextSecondary,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                maxLines = 1
            )
        }
    }
}
