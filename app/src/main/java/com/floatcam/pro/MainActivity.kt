package com.floatcam.pro

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.floatcam.pro.ui.screens.MainScreen
import com.floatcam.pro.ui.screens.OnboardingScreen
import com.floatcam.pro.ui.theme.FloatCamProTheme
import com.floatcam.pro.ui.theme.ObsidianBackground
import com.floatcam.pro.ui.viewmodels.MainViewModel

class MainActivity : ComponentActivity() {

    private val mainViewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            FloatCamProTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = ObsidianBackground
                ) {
                    val isOnboardingCompleted by mainViewModel.isOnboardingCompleted.collectAsState()
                    val permissionState by mainViewModel.permissionState.collectAsState()

                    // If onboarding is done AND all required permissions are granted, show MainScreen.
                    // Otherwise show OnboardingScreen so user can grant permissions.
                    if (isOnboardingCompleted && permissionState.allRequiredGranted) {
                        MainScreen(mainViewModel = mainViewModel)
                    } else {
                        OnboardingScreen(
                            viewModel = mainViewModel,
                            permissionState = permissionState,
                            onComplete = {
                                // Handled via viewModel.completeOnboarding()
                            }
                        )
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        mainViewModel.checkPermissions()
    }
}
