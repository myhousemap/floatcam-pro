package com.floatcam.pro.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.floatcam.pro.data.model.*
import com.floatcam.pro.ui.theme.*
import com.floatcam.pro.ui.viewmodels.SettingsViewModel

@Composable
fun SettingsScreen(viewModel: SettingsViewModel) {
    val settings by viewModel.settings.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ObsidianBackground)
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp)
    ) {
        Text(
            text = "Studio Settings",
            style = MaterialTheme.typography.headlineMedium,
            color = TextPrimary
        )
        Text(
            text = "Customize overlay behavior, video encoding & styling",
            style = MaterialTheme.typography.bodyMedium,
            color = TextSecondary
        )

        Spacer(modifier = Modifier.height(24.dp))

        // 1. Camera & Recording Section
        SettingsSectionHeader(title = "CAMERA & CAPTURE")

        SettingsCard {
            // Resolution
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Default Video Quality",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary
                )
                Text(
                    text = "Safe fallback to 1080p if device sensor doesn't support 4K",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    fontSize = 12.sp
                )
                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    listOf(VideoResolution.HD_720P, VideoResolution.FHD_1080P, VideoResolution.UHD_4K).forEach { res ->
                        FilterChip(
                            selected = settings.resolution == res,
                            onClick = { viewModel.updateResolution(res) },
                            label = { Text(res.label) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = PrimaryBlue.copy(alpha = 0.2f),
                                selectedLabelColor = PrimaryBlue
                            ),
                            border = FilterChipDefaults.filterChipBorder(
                                enabled = true,
                                selected = settings.resolution == res,
                                borderColor = ObsidianBorder,
                                selectedBorderColor = PrimaryBlue
                            )
                        )
                    }
                }
            }

            HorizontalDivider(color = ObsidianBorder)

            // Frame Rate
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Frame Rate Target",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary
                )
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    listOf(FrameRate.FPS_30, FrameRate.FPS_60).forEach { fps ->
                        FilterChip(
                            selected = settings.fps == fps,
                            onClick = { viewModel.updateFps(fps) },
                            label = { Text(fps.label) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = PrimaryBlue.copy(alpha = 0.2f),
                                selectedLabelColor = PrimaryBlue
                            ),
                            border = FilterChipDefaults.filterChipBorder(
                                enabled = true,
                                selected = settings.fps == fps,
                                borderColor = ObsidianBorder,
                                selectedBorderColor = PrimaryBlue
                            )
                        )
                    }
                }
            }

            HorizontalDivider(color = ObsidianBorder)

            // Audio Source
            SettingsSwitchRow(
                title = "Capture Microphone Audio",
                description = "Record system voice alongside video feeds",
                checked = settings.audioEnabled,
                onCheckedChange = { viewModel.updateAudioEnabled(it) }
            )

            HorizontalDivider(color = ObsidianBorder)

            // Mirror Front Camera
            SettingsSwitchRow(
                title = "Mirror Front Camera",
                description = "Horizontally flip preview for natural facecam view",
                checked = settings.mirrorFrontCamera,
                onCheckedChange = { viewModel.updateMirrorFront(it) }
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // 2. Overlay Style & Appearance
        SettingsSectionHeader(title = "OVERLAY & STYLING")

        SettingsCard {
            // Glowing Border Color
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Glowing Border Color",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary
                )
                Text(
                    text = "Highlights overlay boundary against bright backgrounds",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    fontSize = 12.sp
                )
                Spacer(modifier = Modifier.height(12.dp))

                val colorPalette = listOf(
                    0xFF4F8CFF to "Electric Blue",
                    0xFF00F5D4 to "Cyber Neon",
                    0xFFFFB703 to "Amber Gold",
                    0xFFFF4D5A to "Studio Coral",
                    0xFFA855F7 to "Neon Violet",
                    0xFFE2E8F0 to "Stealth Silver"
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    colorPalette.forEach { (colorVal, _) ->
                        val isSelected = settings.borderColor == colorVal
                        Box(
                            modifier = Modifier
                                .size(38.dp)
                                .clip(CircleShape)
                                .background(Color(colorVal))
                                .border(
                                    width = if (isSelected) 3.dp else 1.dp,
                                    color = if (isSelected) Color.White else Color.Transparent,
                                    shape = CircleShape
                                )
                                .clickable { viewModel.updateBorderColor(colorVal) },
                            contentAlignment = Alignment.Center
                        ) {
                            if (isSelected) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = null,
                                    tint = Color.Black,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    }
                }
            }

            HorizontalDivider(color = ObsidianBorder)

            // Border Width
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Border Width: ${settings.borderWidthDp}dp",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary
                )
                Spacer(modifier = Modifier.height(6.dp))
                Slider(
                    value = settings.borderWidthDp.toFloat(),
                    onValueChange = { viewModel.updateBorderWidth(it.toInt()) },
                    valueRange = 1f..5f,
                    steps = 3,
                    colors = SliderDefaults.colors(
                        thumbColor = PrimaryBlue,
                        activeTrackColor = PrimaryBlue
                    )
                )
            }

            HorizontalDivider(color = ObsidianBorder)

            // Auto-hide HUD Timeout
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Auto-Hide Controls Timeout",
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary
                )
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    listOf(2, 3, 5, 8).forEach { secs ->
                        FilterChip(
                            selected = settings.autoHideHudTimeoutSec == secs,
                            onClick = { viewModel.updateAutoHideHudTimeout(secs) },
                            label = { Text("${secs}s") },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = PrimaryBlue.copy(alpha = 0.2f),
                                selectedLabelColor = PrimaryBlue
                            ),
                            border = FilterChipDefaults.filterChipBorder(
                                enabled = true,
                                selected = settings.autoHideHudTimeoutSec == secs,
                                borderColor = ObsidianBorder,
                                selectedBorderColor = PrimaryBlue
                            )
                        )
                    }
                }
            }

            HorizontalDivider(color = ObsidianBorder)

            // Keep Screen On
            SettingsSwitchRow(
                title = "Keep Screen On While Recording",
                description = "Prevents device display from sleeping during active captures",
                checked = settings.keepScreenOn,
                onCheckedChange = { viewModel.updateKeepScreenOn(it) }
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // 3. App Details Card
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, ObsidianBorder, RoundedCornerShape(18.dp)),
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(containerColor = ObsidianSurface)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "FloatCam Pro",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
                Text(
                    text = "Version 1.0.0 • Production Build",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    fontSize = 12.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Built with CameraX, WindowManager LifecycleService, Jetpack Compose Material 3, and Scoped Storage MediaStore.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextMuted,
                    fontSize = 11.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun SettingsSectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelSmall,
        color = TextSecondary,
        fontWeight = FontWeight.Bold,
        fontSize = 11.sp,
        modifier = Modifier.padding(start = 4.dp, bottom = 8.dp)
    )
}

@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, ObsidianBorder, RoundedCornerShape(18.dp)),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = ObsidianSurface),
        content = content
    )
}

@Composable
private fun SettingsSwitchRow(
    title: String,
    description: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
                fontSize = 12.sp
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = PrimaryBlue,
                uncheckedTrackColor = ObsidianSurfaceVariant
            )
        )
    }
}
