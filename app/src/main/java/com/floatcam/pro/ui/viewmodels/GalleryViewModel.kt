package com.floatcam.pro.ui.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.floatcam.pro.data.model.MediaItem
import com.floatcam.pro.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class GalleryViewModel(application: Application) : AndroidViewModel(application) {

    private val mediaRepository = MediaRepository(application)

    private val _mediaItems = MutableStateFlow<List<MediaItem>>(emptyList())
    val mediaItems: StateFlow<List<MediaItem>> = _mediaItems.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _selectedItem = MutableStateFlow<MediaItem?>(null)
    val selectedItem: StateFlow<MediaItem?> = _selectedItem.asStateFlow()

    init {
        loadMedia()
    }

    fun loadMedia() {
        viewModelScope.launch {
            _isLoading.value = true
            mediaRepository.getMediaList().collect { items ->
                _mediaItems.value = items
                _isLoading.value = false
            }
        }
    }

    fun selectItem(item: MediaItem?) {
        _selectedItem.value = item
    }

    fun deleteMedia(item: MediaItem) {
        viewModelScope.launch {
            val success = mediaRepository.deleteMedia(item.uri)
            if (success) {
                _mediaItems.value = _mediaItems.value.filter { it.id != item.id }
                if (_selectedItem.value?.id == item.id) {
                    _selectedItem.value = null
                }
            }
        }
    }
}
