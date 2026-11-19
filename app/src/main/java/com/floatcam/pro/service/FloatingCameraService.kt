package com.floatcam.pro.service

import android.animation.ObjectAnimator
import android.annotation.SuppressLint
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.*
import android.provider.MediaStore
import android.util.DisplayMetrics
import android.view.*
import android.widget.ImageButton
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.camera.video.VideoCapture
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import com.floatcam.pro.R
import com.floatcam.pro.data.model.*
import com.floatcam.pro.data.repository.SettingsRepository
import com.floatcam.pro.utils.HapticUtils
import com.floatcam.pro.utils.NotificationHelper
import com.floatcam.pro.utils.PermissionUtils
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min

class FloatingCameraService : LifecycleService() {

    companion object {
        const val ACTION_START_SERVICE = "com.floatcam.pro.START_SERVICE"
        const val ACTION_STOP_SERVICE = "com.floatcam.pro.STOP_SERVICE"
        const val ACTION_TOGGLE_WINDOW = "com.floatcam.pro.TOGGLE_WINDOW"
        const val ACTION_TOGGLE_RECORD = "com.floatcam.pro.TOGGLE_RECORD"

        private val _isServiceRunning = MutableStateFlow(false)
        val isServiceRunning = _isServiceRunning.asStateFlow()

        private val _isRecordingActive = MutableStateFlow(false)
        val isRecordingActive = _isRecordingActive.asStateFlow()
    }

    private lateinit var windowManager: WindowManager
    private lateinit var settingsRepository: SettingsRepository
    private var overlayView: View? = null
    private lateinit var windowParams: WindowManager.LayoutParams

    // Views inside overlay
    private var windowContainer: View? = null
    private var borderFrame: View? = null
    private var previewContainer: View? = null
    private var previewView: PreviewView? = null
    private var touchOverlayView: View? = null
    private var hudContainer: View? = null
    private var topBar: View? = null
    private var bottomBar: View? = null
    private var recordingBadge: View? = null
    private var tvRecordingTimer: TextView? = null
    private var recordingPulseDot: View? = null
    private var btnTorch: ImageButton? = null
    private var btnMirror: ImageButton? = null
    private var btnShape: ImageButton? = null
    private var btnLock: ImageButton? = null
    private var btnMinimize: ImageButton? = null
    private var btnClose: ImageButton? = null
    private var tvOpacityLabel: TextView? = null
    private var sbOpacity: SeekBar? = null
    private var btnFlipCamera: ImageButton? = null
    private var btnShutter: ImageButton? = null
    private var btnRecord: ImageButton? = null
    private var btnPauseResume: ImageButton? = null
    private var resizeHandle: View? = null
    private var minimizedBubble: View? = null
    private var bubbleRecordingDot: View? = null

    // CameraX state
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var previewUseCase: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null

    // Window & Gesture state
    private var currentSettings = CameraSettings()
    private var isTorchOn = false
    private var isLocked = false
    private var isMinimized = false
    private var isPaused = false
    private var isHudVisible = true
    private var recordingSeconds = 0
    private val timerHandler = Handler(Looper.getMainLooper())
    private val hudHideHandler = Handler(Looper.getMainLooper())

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var initialWidth = 0
    private var initialHeight = 0
    private var isResizing = false
    private var isDragging = false

    private lateinit var scaleGestureDetector: ScaleGestureDetector

    private val recordingTimerRunnable = object : Runnable {
        override fun run() {
            if (_isRecordingActive.value && !isPaused) {
                recordingSeconds++
                val mins = recordingSeconds / 60
                val secs = recordingSeconds % 60
                val formatted = String.format(Locale.getDefault(), "%02d:%02d", mins, secs)
                tvRecordingTimer?.text = formatted

                // Pulse the dot
                recordingPulseDot?.alpha = if (recordingSeconds % 2 == 0) 1.0f else 0.3f

                // Update notification periodically
                val notification = NotificationHelper.buildNotification(
                    this@FloatingCameraService,
                    isRecording = true,
                    recordingDurationText = formatted,
                    isWindowVisible = !isMinimized
                )
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NotificationHelper.NOTIFICATION_ID, notification)
            }
            timerHandler.postDelayed(this, 1000)
        }
    }

    private val autoHideHudRunnable = Runnable {
        hideHud()
    }

    override fun onCreate() {
        super.onCreate()
        _isServiceRunning.value = true
        settingsRepository = SettingsRepository(this)
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        NotificationHelper.createNotificationChannel(this)

        startInForeground()

        lifecycleScope.launch {
            currentSettings = settingsRepository.settingsFlow.first()
            initOverlayView()
            setupCamera()
        }
    }

    private fun startInForeground() {
        val notification = NotificationHelper.buildNotification(
            this,
            isRecording = false,
            isWindowVisible = true
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val hasMic = PermissionUtils.hasRecordAudioPermission(this)
            val type = if (hasMic) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            }
            startForeground(NotificationHelper.NOTIFICATION_ID, notification, type)
        } else {
            startForeground(NotificationHelper.NOTIFICATION_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            ACTION_STOP_SERVICE -> {
                stopSelf()
            }
            ACTION_TOGGLE_WINDOW -> {
                toggleWindowMinimize()
            }
            ACTION_TOGGLE_RECORD -> {
                toggleRecording()
            }
        }
        return START_STICKY
    }

    @SuppressLint("InflateParams", "ClickableViewAccessibility")
    private fun initOverlayView() {
        val inflater = LayoutInflater.from(this)
        overlayView = inflater.inflate(R.layout.overlay_camera_view, null)

        windowContainer = overlayView?.findViewById(R.id.windowContainer)
        borderFrame = overlayView?.findViewById(R.id.borderFrame)
        previewContainer = overlayView?.findViewById(R.id.previewContainer)
        previewView = overlayView?.findViewById(R.id.previewView)
        touchOverlayView = overlayView?.findViewById(R.id.touchOverlayView)
        hudContainer = overlayView?.findViewById(R.id.hudContainer)
        topBar = overlayView?.findViewById(R.id.topBar)
        bottomBar = overlayView?.findViewById(R.id.bottomBar)
        recordingBadge = overlayView?.findViewById(R.id.recordingBadge)
        tvRecordingTimer = overlayView?.findViewById(R.id.tvRecordingTimer)
        recordingPulseDot = overlayView?.findViewById(R.id.recordingPulseDot)
        btnTorch = overlayView?.findViewById(R.id.btnTorch)
        btnMirror = overlayView?.findViewById(R.id.btnMirror)
        btnShape = overlayView?.findViewById(R.id.btnShape)
        btnLock = overlayView?.findViewById(R.id.btnLock)
        btnMinimize = overlayView?.findViewById(R.id.btnMinimize)
        btnClose = overlayView?.findViewById(R.id.btnClose)
        tvOpacityLabel = overlayView?.findViewById(R.id.tvOpacityLabel)
        sbOpacity = overlayView?.findViewById(R.id.sbOpacity)
        btnFlipCamera = overlayView?.findViewById(R.id.btnFlipCamera)
        btnShutter = overlayView?.findViewById(R.id.btnShutter)
        btnRecord = overlayView?.findViewById(R.id.btnRecord)
        btnPauseResume = overlayView?.findViewById(R.id.btnPauseResume)
        resizeHandle = overlayView?.findViewById(R.id.resizeHandle)
        minimizedBubble = overlayView?.findViewById(R.id.minimizedBubble)
        bubbleRecordingDot = overlayView?.findViewById(R.id.bubbleRecordingDot)

        // Window Params
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val displayMetrics = resources.displayMetrics
        val initialSizePx = (220 * displayMetrics.density).toInt()

        windowParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (displayMetrics.widthPixels - initialSizePx) / 2
            y = (displayMetrics.heightPixels - initialSizePx) / 3
        }

        windowContainer?.layoutParams?.width = initialSizePx
        windowContainer?.layoutParams?.height = initialSizePx

        // Apply initial shape, border and opacity
        applyShapePreset(currentSettings.shape)
        applyBorderStyling()
        applyOpacity(currentSettings.opacity)

        setupGestures()
        setupListeners()

        windowManager.addView(overlayView, windowParams)
        scheduleAutoHideHud()
    }

    private fun applyShapePreset(shape: ShapePreset) {
        currentSettings = currentSettings.copy(shape = shape)
        val density = resources.displayMetrics.density

        previewContainer?.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                when (shape) {
                    ShapePreset.CIRCLE -> {
                        outline.setOval(0, 0, view.width, view.height)
                    }
                    ShapePreset.SQUARE_1_1 -> {
                        val radius = 24 * density
                        outline.setRoundRect(0, 0, view.width, view.height, radius)
                    }
                    ShapePreset.PORTRAIT_9_16 -> {
                        val radius = 20 * density
                        outline.setRoundRect(0, 0, view.width, view.height, radius)
                    }
                    ShapePreset.LANDSCAPE_16_9 -> {
                        val radius = 20 * density
                        outline.setRoundRect(0, 0, view.width, view.height, radius)
                    }
                }
            }
        }
        previewContainer?.clipToOutline = true

        // Adjust dimensions to fit shape ratio
        windowContainer?.let { container ->
            val curWidth = container.layoutParams.width
            val newHeight = when (shape) {
                ShapePreset.CIRCLE, ShapePreset.SQUARE_1_1 -> curWidth
                ShapePreset.PORTRAIT_9_16 -> (curWidth * 16) / 9
                ShapePreset.LANDSCAPE_16_9 -> (curWidth * 9) / 16
            }
            container.layoutParams.height = newHeight
            container.requestLayout()
        }
    }

    private fun applyBorderStyling() {
        val drawable = GradientDrawable().apply {
            val density = resources.displayMetrics.density
            val radius = when (currentSettings.shape) {
                ShapePreset.CIRCLE -> 9999f
                else -> 24f * density
            }
            cornerRadius = radius
            setColor(Color.parseColor("#800B0D12"))
            setStroke(
                (currentSettings.borderWidthDp * density).toInt(),
                currentSettings.borderColor.toInt()
            )
        }
        borderFrame?.background = drawable
    }

    private fun applyOpacity(opacity: Float) {
        val clamped = opacity.coerceIn(0.3f, 1.0f)
        currentSettings = currentSettings.copy(opacity = clamped)
        windowContainer?.alpha = clamped
        tvOpacityLabel?.text = "${(clamped * 100).toInt()}%"
        val progress = ((clamped - 0.3f) / 0.7f * 70).toInt()
        sbOpacity?.progress = progress
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupGestures() {
        scaleGestureDetector = ScaleGestureDetector(this, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                camera?.cameraInfo?.zoomState?.value?.let { zoomState ->
                    val currentRatio = zoomState.zoomRatio
                    val delta = detector.scaleFactor
                    val targetRatio = (currentRatio * delta).coerceIn(
                        zoomState.minZoomRatio,
                        zoomState.maxZoomRatio
                    )
                    camera?.cameraControl?.setZoomRatio(targetRatio)
                }
                return true
            }
        })

        // Preview Touch Overlay: Single tap toggles HUD, scale detector pinches to zoom, drag moves window
        touchOverlayView?.setOnTouchListener { view, event ->
            scaleGestureDetector.onTouchEvent(event)

            if (!scaleGestureDetector.isInProgress) {
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = windowParams.x
                        initialY = windowParams.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isDragging = false
                        resetAutoHideHud()
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        if (!isLocked && (Math.abs(dx) > 10 || Math.abs(dy) > 10)) {
                            isDragging = true
                            windowParams.x = initialX + dx
                            windowParams.y = initialY + dy
                            clampWindowPosition()
                            windowManager.updateViewLayout(overlayView, windowParams)
                        }
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!isDragging) {
                            toggleHud()
                        }
                    }
                }
            }
            true
        }

        // Corner Resize Handle Touch Listener
        resizeHandle?.setOnTouchListener { _, event ->
            if (isLocked) return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    isResizing = true
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    initialWidth = windowContainer?.layoutParams?.width ?: 200
                    initialHeight = windowContainer?.layoutParams?.height ?: 200
                    resetAutoHideHud()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (isResizing) {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val metrics = resources.displayMetrics
                        val minWidth = (130 * metrics.density).toInt()
                        val maxWidth = metrics.widthPixels - 30

                        val newWidth = (initialWidth + dx).coerceIn(minWidth, maxWidth)
                        val newHeight = when (currentSettings.shape) {
                            ShapePreset.CIRCLE, ShapePreset.SQUARE_1_1 -> newWidth
                            ShapePreset.PORTRAIT_9_16 -> (newWidth * 16) / 9
                            ShapePreset.LANDSCAPE_16_9 -> (newWidth * 9) / 16
                        }

                        windowContainer?.layoutParams?.width = newWidth
                        windowContainer?.layoutParams?.height = newHeight
                        windowContainer?.requestLayout()
                        previewContainer?.invalidateOutline()
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    isResizing = false
                    HapticUtils.performSnapHaptic(this)
                    true
                }
                else -> false
            }
        }

        // Minimized Bubble Drag & Click
        minimizedBubble?.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = windowParams.x
                    initialY = windowParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        isDragging = true
                        windowParams.x = initialX + dx
                        windowParams.y = initialY + dy
                        windowManager.updateViewLayout(overlayView, windowParams)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        toggleWindowMinimize()
                    } else {
                        // Snap bubble to nearest screen edge (left or right)
                        val screenWidth = resources.displayMetrics.widthPixels
                        val bubbleWidth = minimizedBubble?.width ?: 56
                        val targetX = if (windowParams.x + bubbleWidth / 2 < screenWidth / 2) {
                            16
                        } else {
                            screenWidth - bubbleWidth - 16
                        }
                        windowParams.x = targetX
                        windowManager.updateViewLayout(overlayView, windowParams)
                        HapticUtils.performSnapHaptic(this)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun clampWindowPosition() {
        val metrics = resources.displayMetrics
        val width = windowContainer?.width ?: 200
        val height = windowContainer?.height ?: 200

        windowParams.x = windowParams.x.coerceIn(0, max(0, metrics.widthPixels - width))
        windowParams.y = windowParams.y.coerceIn(50, max(50, metrics.heightPixels - height - 100))
    }

    private fun setupListeners() {
        btnTorch?.setOnClickListener {
            HapticUtils.performClick(it)
            toggleTorch()
            resetAutoHideHud()
        }

        btnMirror?.setOnClickListener {
            HapticUtils.performClick(it)
            val newMirror = !currentSettings.mirrorFrontCamera
            currentSettings = currentSettings.copy(mirrorFrontCamera = newMirror)
            lifecycleScope.launch { settingsRepository.updateMirrorFront(newMirror) }
            updateMirrorEffect()
            resetAutoHideHud()
        }

        btnShape?.setOnClickListener {
            HapticUtils.performClick(it)
            cycleShapePreset()
            resetAutoHideHud()
        }

        btnLock?.setOnClickListener {
            HapticUtils.performClick(it)
            isLocked = !isLocked
            btnLock?.setImageResource(if (isLocked) R.drawable.ic_lock else R.drawable.ic_unlock)
            resizeHandle?.visibility = if (isLocked) View.GONE else View.VISIBLE
            Toast.makeText(this, if (isLocked) "Overlay Locked" else "Overlay Unlocked", Toast.LENGTH_SHORT).show()
            resetAutoHideHud()
        }

        btnMinimize?.setOnClickListener {
            HapticUtils.performClick(it)
            toggleWindowMinimize()
        }

        btnClose?.setOnClickListener {
            HapticUtils.performClick(it)
            stopSelf()
        }

        sbOpacity?.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    val opacity = 0.3f + (progress / 70f) * 0.7f
                    applyOpacity(opacity)
                    lifecycleScope.launch { settingsRepository.updateOpacity(opacity) }
                    resetAutoHideHud()
                }
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        btnFlipCamera?.setOnClickListener {
            HapticUtils.performClick(it)
            flipCamera()
            resetAutoHideHud()
        }

        btnShutter?.setOnClickListener {
            HapticUtils.performClick(it)
            takePhoto()
            resetAutoHideHud()
        }

        btnRecord?.setOnClickListener {
            HapticUtils.performClick(it)
            toggleRecording()
            resetAutoHideHud()
        }

        btnPauseResume?.setOnClickListener {
            HapticUtils.performClick(it)
            togglePauseResumeRecording()
            resetAutoHideHud()
        }
    }

    private fun toggleWindowMinimize() {
        isMinimized = !isMinimized
        HapticUtils.performSnapHaptic(this)
        if (isMinimized) {
            windowContainer?.visibility = View.GONE
            minimizedBubble?.visibility = View.VISIBLE
            bubbleRecordingDot?.visibility = if (_isRecordingActive.value) View.VISIBLE else View.GONE
        } else {
            minimizedBubble?.visibility = View.GONE
            windowContainer?.visibility = View.VISIBLE
            resetAutoHideHud()
        }
        val notification = NotificationHelper.buildNotification(
            this,
            isRecording = _isRecordingActive.value,
            recordingDurationText = tvRecordingTimer?.text?.toString() ?: "",
            isWindowVisible = !isMinimized
        )
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NotificationHelper.NOTIFICATION_ID, notification)
    }

    private fun cycleShapePreset() {
        val next = when (currentSettings.shape) {
            ShapePreset.CIRCLE -> ShapePreset.SQUARE_1_1
            ShapePreset.SQUARE_1_1 -> ShapePreset.PORTRAIT_9_16
            ShapePreset.PORTRAIT_9_16 -> ShapePreset.LANDSCAPE_16_9
            ShapePreset.LANDSCAPE_16_9 -> ShapePreset.CIRCLE
        }
        applyShapePreset(next)
        applyBorderStyling()
        lifecycleScope.launch { settingsRepository.updateShape(next) }
    }

    private fun toggleTorch() {
        if (currentSettings.lens == CameraLens.FRONT) {
            Toast.makeText(this, "Torch not available on front camera", Toast.LENGTH_SHORT).show()
            return
        }
        isTorchOn = !isTorchOn
        camera?.cameraControl?.enableTorch(isTorchOn)
        btnTorch?.setImageResource(if (isTorchOn) R.drawable.ic_flash_on else R.drawable.ic_flash_off)
    }

    private fun updateMirrorEffect() {
        if (currentSettings.lens == CameraLens.FRONT && currentSettings.mirrorFrontCamera) {
            previewView?.scaleX = -1f
        } else {
            previewView?.scaleX = 1f
        }
    }

    private fun toggleHud() {
        if (isHudVisible) {
            hideHud()
        } else {
            showHud()
            scheduleAutoHideHud()
        }
    }

    private fun showHud() {
        isHudVisible = true
        hudContainer?.visibility = View.VISIBLE
        hudContainer?.let {
            ObjectAnimator.ofFloat(it, View.ALPHA, 0f, 1f).apply {
                duration = 200
                start()
            }
        }
    }

    private fun hideHud() {
        isHudVisible = false
        hudContainer?.let {
            ObjectAnimator.ofFloat(it, View.ALPHA, 1f, 0f).apply {
                duration = 200
                start()
            }
        }
    }

    private fun scheduleAutoHideHud() {
        hudHideHandler.removeCallbacks(autoHideHudRunnable)
        hudHideHandler.postDelayed(autoHideHudRunnable, TimeUnit.SECONDS.toMillis(currentSettings.autoHideHudTimeoutSec.toLong()))
    }

    private fun resetAutoHideHud() {
        if (!isHudVisible) {
            showHud()
        }
        scheduleAutoHideHud()
    }

    private fun flipCamera() {
        val newLens = if (currentSettings.lens == CameraLens.FRONT) CameraLens.BACK else CameraLens.FRONT
        currentSettings = currentSettings.copy(lens = newLens)
        isTorchOn = false
        btnTorch?.setImageResource(R.drawable.ic_flash_off)
        lifecycleScope.launch { settingsRepository.updateLens(newLens) }
        bindCameraUseCases()
    }

    private fun setupCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            bindCameraUseCases()
        }, ContextCompat.getMainExecutor(this))
    }

    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: return
        val previewV = previewView ?: return

        provider.unbindAll()

        val cameraSelector = if (currentSettings.lens == CameraLens.FRONT) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }

        // Preview UseCase
        previewUseCase = Preview.Builder().build().also {
            it.surfaceProvider = previewV.surfaceProvider
        }

        // ImageCapture UseCase
        imageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .build()

        // VideoCapture UseCase with Quality Fallback Strategy
        val quality = when (currentSettings.resolution) {
            VideoResolution.SD_480P -> Quality.SD
            VideoResolution.HD_720P -> Quality.HD
            VideoResolution.FHD_1080P -> Quality.FHD
            VideoResolution.UHD_4K -> Quality.UHD
        }
        val qualitySelector = QualitySelector.from(
            quality,
            FallbackStrategy.lowerQualityOrHigherThan(Quality.FHD)
        )
        val recorder = Recorder.Builder()
            .setQualitySelector(qualitySelector)
            .build()
        videoCapture = VideoCapture.withOutput(recorder)

        runCatching {
            camera = provider.bindToLifecycle(
                this,
                cameraSelector,
                previewUseCase,
                imageCapture,
                videoCapture
            )
            updateMirrorEffect()
        }.onFailure { e ->
            Toast.makeText(this, "Failed to bind camera: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun takePhoto() {
        val capture = imageCapture ?: return
        HapticUtils.performRecordHaptic(this)

        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val fileName = "FloatCam_IMG_$timeStamp.jpg"

        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/FloatCamPro")
            }
        }

        val outputOptions = ImageCapture.OutputFileOptions.Builder(
            contentResolver,
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            contentValues
        ).build()

        capture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    Toast.makeText(this@FloatingCameraService, "Photo saved: $fileName", Toast.LENGTH_SHORT).show()
                }

                override fun onError(exception: ImageCaptureException) {
                    Toast.makeText(this@FloatingCameraService, "Capture error: ${exception.message}", Toast.LENGTH_SHORT).show()
                }
            }
        )
    }

    private fun toggleRecording() {
        if (_isRecordingActive.value) {
            stopRecording()
        } else {
            startRecording()
        }
    }

    @SuppressLint("MissingPermission")
    private fun startRecording() {
        val videoCap = videoCapture ?: return
        HapticUtils.performRecordHaptic(this)

        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val fileName = "FloatCam_VID_$timeStamp.mp4"

        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/FloatCamPro")
            }
        }

        val mediaStoreOutput = MediaStoreOutputOptions.Builder(
            contentResolver,
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        ).setContentValues(contentValues).build()

        var pendingRecording = videoCap.output.prepareRecording(this, mediaStoreOutput)

        // Add Audio if enabled and permission granted
        val canRecordAudio = PermissionUtils.hasRecordAudioPermission(this) && currentSettings.audioEnabled
        if (canRecordAudio) {
            runCatching {
                pendingRecording = pendingRecording.withAudioEnabled()
            }
        }

        activeRecording = pendingRecording.start(ContextCompat.getMainExecutor(this)) { recordEvent ->
            when (recordEvent) {
                is VideoRecordEvent.Start -> {
                    _isRecordingActive.value = true
                    isPaused = false
                    recordingSeconds = 0
                    tvRecordingTimer?.text = "00:00"
                    recordingBadge?.visibility = View.VISIBLE
                    btnPauseResume?.visibility = View.VISIBLE
                    btnRecord?.setImageResource(R.drawable.ic_record_stop)
                    bubbleRecordingDot?.visibility = if (isMinimized) View.VISIBLE else View.GONE
                    timerHandler.post(recordingTimerRunnable)
                }
                is VideoRecordEvent.Pause -> {
                    isPaused = true
                    btnPauseResume?.setImageResource(R.drawable.ic_play)
                }
                is VideoRecordEvent.Resume -> {
                    isPaused = false
                    btnPauseResume?.setImageResource(R.drawable.ic_pause)
                }
                is VideoRecordEvent.Finalize -> {
                    _isRecordingActive.value = false
                    isPaused = false
                    timerHandler.removeCallbacks(recordingTimerRunnable)
                    recordingBadge?.visibility = View.GONE
                    btnPauseResume?.visibility = View.GONE
                    btnRecord?.setImageResource(R.drawable.ic_record_start)
                    bubbleRecordingDot?.visibility = View.GONE

                    if (recordEvent.hasError()) {
                        Toast.makeText(this, "Recording failed: ${recordEvent.cause?.message}", Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(this, "Video saved: $fileName", Toast.LENGTH_SHORT).show()
                    }

                    // Reset notification
                    val notification = NotificationHelper.buildNotification(
                        this,
                        isRecording = false,
                        isWindowVisible = !isMinimized
                    )
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.notify(NotificationHelper.NOTIFICATION_ID, notification)
                }
            }
        }
    }

    private fun togglePauseResumeRecording() {
        val rec = activeRecording ?: return
        if (isPaused) {
            rec.resume()
        } else {
            rec.pause()
        }
    }

    private fun stopRecording() {
        HapticUtils.performRecordHaptic(this)
        activeRecording?.stop()
        activeRecording = null
    }

    override fun onDestroy() {
        super.onDestroy()
        _isServiceRunning.value = false
        _isRecordingActive.value = false
        timerHandler.removeCallbacks(recordingTimerRunnable)
        hudHideHandler.removeCallbacks(autoHideHudRunnable)

        runCatching { activeRecording?.stop() }
        runCatching { cameraProvider?.unbindAll() }

        if (overlayView != null) {
            runCatching { windowManager.removeView(overlayView) }
            overlayView = null
        }
    }
}
