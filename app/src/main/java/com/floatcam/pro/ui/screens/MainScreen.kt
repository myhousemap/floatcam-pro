package com.floatcam.pro.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.floatcam.pro.ui.theme.*
import com.floatcam.pro.ui.viewmodels.GalleryViewModel
import com.floatcam.pro.ui.viewmodels.MainViewModel
import com.floatcam.pro.ui.viewmodels.SettingsViewModel

enum class MainTab(val title: String, val icon: ImageVector) {
    STUDIO("Studio", Icons.Default.Videocam),
    GALLERY("Gallery", Icons.Default.PhotoLibrary),
    SETTINGS("Settings", Icons.Default.Settings)
}

@Composable
fun MainScreen(
    mainViewModel: MainViewModel,
    galleryViewModel: GalleryViewModel = viewModel(),
    settingsViewModel: SettingsViewModel = viewModel()
) {
    var selectedTab by remember { mutableStateOf(MainTab.STUDIO) }

    Scaffold(
        containerColor = ObsidianBackground,
        bottomBar = {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .border(1.dp, ObsidianBorder, RoundedCornerShape(22.dp)),
                color = ObsidianSurface,
                tonalElevation = 4.dp
            ) {
                NavigationBar(
                    containerColor = Color.Transparent,
                    tonalElevation = 0.dp,
                    modifier = Modifier.height(64.dp)
                ) {
                    MainTab.values().forEach { tab ->
                        val isSelected = selectedTab == tab
                        NavigationBarItem(
                            selected = isSelected,
                            onClick = { selectedTab = tab },
                            icon = {
                                Icon(
                                    imageVector = tab.icon,
                                    contentDescription = tab.title,
                                    tint = if (isSelected) PrimaryBlue else TextSecondary
                                )
                            },
                            label = {
                                Text(
                                    text = tab.title,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = if (isSelected) PrimaryBlue else TextSecondary
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                indicatorColor = PrimaryBlue.copy(alpha = 0.15f)
                            )
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = innerPadding.calculateBottomPadding())
        ) {
            AnimatedContent(
                targetState = selectedTab,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "tabContent"
            ) { tab ->
                when (tab) {
                    MainTab.STUDIO -> StudioScreen(viewModel = mainViewModel)
                    MainTab.GALLERY -> GalleryScreen(viewModel = galleryViewModel)
                    MainTab.SETTINGS -> SettingsScreen(viewModel = settingsViewModel)
                }
            }
        }
    }
}
