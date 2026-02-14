// Global Variables
let recognition;
let isRecording = false;
let currentTranscription = '';
let transcriptionHistory = [];
let settings = {
    darkMode: false,
    fontSize: 'medium',
    language: 'en-US',
    autoSave: false,
    volumeIndicator: true
};

// Initialize App
document.addEventListener('DOMContentLoaded', function() {
    loadSettings();
    loadHistory();
    initializeSpeechRecognition();
    setupNavigation();
    applySettings();
});

// Navigation
function setupNavigation() {
    const navLinks = document.querySelectorAll('.nav-link');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const pageName = this.dataset.page;
            showPage(pageName);
            
            // Update active nav link
            navLinks.forEach(l => l.classList.remove('active'));
            this.classList.add('active');
        });
    });
}

function showPage(pageName) {
    const pages = document.querySelectorAll('.page');
    pages.forEach(page => page.classList.remove('active'));
    
    const targetPage = document.getElementById(`${pageName}-page`);
    if (targetPage) {
        targetPage.classList.add('active');
    }
}

// Speech Recognition
function initializeSpeechRecognition() {
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        recognition = new SpeechRecognition();
        
        recognition.continuous = true;
        recognition.interimResults = true;
        recognition.lang = settings.language;

        recognition.onstart = function() {
            updateStatus('Recording... Speak now!', true);
            document.getElementById('recordBtn').textContent = '⏹️ Stop Recording';
            document.getElementById('recordBtn').classList.add('recording');
            isRecording = true;
        };

        recognition.onresult = function(event) {
            let finalTranscript = '';
            let interimTranscript = '';

            for (let i = event.resultIndex; i < event.results.length; i++) {
                const transcript = event.results[i][0].transcript;
                if (event.results[i].isFinal) {
                    finalTranscript += transcript + ' ';
                } else {
                    interimTranscript += transcript;
                }
            }

            currentTranscription += finalTranscript;
            updateTranscription(currentTranscription + interimTranscript);
        };

        recognition.onerror = function(event) {
            console.error('Speech recognition error:', event.error);
            updateStatus(`Error: ${event.error}`, false);
            stopRecording();
        };

        recognition.onend = function() {
            if (isRecording) {
                // Restart recognition if it ended unexpectedly
                recognition.start();
            }
        };

    } else {
        updateStatus('Speech recognition not supported in this browser', false);
        document.getElementById('recordBtn').disabled = true;
    }
}

function toggleRecording() {
    if (!isRecording) {
        startRecording();
    } else {
        stopRecording();
    }
}

function startRecording() {
    if (recognition) {
        currentTranscription = '';
        recognition.lang = settings.language;
        recognition.start();
    }
}

function stopRecording() {
    if (recognition) {
        recognition.stop();
    }
    isRecording = false;
    document.getElementById('recordBtn').textContent = '🎤 Start Recording';
    document.getElementById('recordBtn').classList.remove('recording');
    updateStatus('Recording stopped', false);
    
    if (currentTranscription.trim()) {
        document.getElementById('saveBtn').style.display = 'inline-block';
        if (settings.autoSave) {
            saveTranscription();
        }
    }
}

function updateStatus(message, isRecording) {
    const statusText = document.getElementById('statusText');
    const statusIndicator = document.getElementById('statusIndicator');
    
    statusText.textContent = message;
    
    if (isRecording) {
        statusIndicator.classList.add('recording');
    } else {
        statusIndicator.classList.remove('recording');
    }
}

function updateTranscription(text) {
    document.getElementById('currentTranscription').textContent = text;
}

function clearCurrent() {
    currentTranscription = '';
    document.getElementById('currentTranscription').textContent = 'Click "Start Recording" to begin transcription...';
    document.getElementById('saveBtn').style.display = 'none';
}

function saveTranscription() {
    if (!currentTranscription.trim()) return;
    
    const transcriptionItem = {
        id: Date.now(),
        text: currentTranscription.trim(),
        date: new Date().toISOString(),
        language: settings.language
    };
    
    transcriptionHistory.unshift(transcriptionItem);
    saveHistory();
    loadHistory();
    
    // Show success message
    updateStatus('Transcription saved to history!', false);
    document.getElementById('saveBtn').style.display = 'none';
    
    // Clear current transcription
    setTimeout(() => {
        clearCurrent();
    }, 2000);
}

// History Management
function loadHistory() {
    const saved = localStorage.getItem('speechHistory');
    if (saved) {
        transcriptionHistory = JSON.parse(saved);
    }
    displayHistory();
}

function saveHistory() {
    localStorage.setItem('speechHistory', JSON.stringify(transcriptionHistory));
}

function displayHistory() {
    const historyList = document.getElementById('historyList');
    const emptyHistory = document.getElementById('emptyHistory');
    
    if (transcriptionHistory.length === 0) {
        historyList.style.display = 'none';
        emptyHistory.style.display = 'block';
        return;
    }
    
    historyList.style.display = 'grid';
    emptyHistory.style.display = 'none';
    
    historyList.innerHTML = transcriptionHistory.map(item => `
        <div class="history-item">
            <div class="history-item-header">
                <span class="history-item-date">${formatDate(item.date)}</span>
                <span class="history-item-language">${item.language}</span>
            </div>
            <div class="history-item-text">${escapeHtml(item.text)}</div>
            <div class="history-item-actions">
                <button class="btn-copy" onclick="copyToClipboard(${item.id})">📋 Copy</button>
                <button class="btn-delete" onclick="deleteFromHistory(${item.id})">🗑️ Delete</button>
            </div>
        </div>
    `).join('');
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString();
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function copyToClipboard(id) {
    const item = transcriptionHistory.find(h => h.id === id);
    if (item) {
        navigator.clipboard.writeText(item.text).then(() => {
            updateStatus('Copied to clipboard!', false);
        });
    }
}

function deleteFromHistory(id) {
    transcriptionHistory = transcriptionHistory.filter(h => h.id !== id);
    saveHistory();
    displayHistory();
}

function clearHistory() {
    if (confirm('Are you sure you want to clear all history? This cannot be undone.')) {
        transcriptionHistory = [];
        saveHistory();
        displayHistory();
        updateStatus('History cleared', false);
    }
}

function exportHistory() {
    if (transcriptionHistory.length === 0) {
        updateStatus('No history to export', false);
        return;
    }
    
    const exportData = transcriptionHistory.map(item => ({
        date: formatDate(item.date),
        language: item.language,
        text: item.text
    }));
    
    const dataStr = JSON.stringify(exportData, null, 2);
    const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
    
    const exportFileDefaultName = `speech-history-${new Date().toISOString().split('T')[0]}.json`;
    
    const linkElement = document.createElement('a');
    linkElement.setAttribute('href', dataUri);
    linkElement.setAttribute('download', exportFileDefaultName);
    linkElement.click();
    
    updateStatus('History exported successfully', false);
}

// Settings Management
function loadSettings() {
    const saved = localStorage.getItem('speechSettings');
    if (saved) {
        settings = { ...settings, ...JSON.parse(saved) };
    }
    applySettings();
}

function saveSettings() {
    localStorage.setItem('speechSettings', JSON.stringify(settings));
}

function applySettings() {
    // Dark mode
    if (settings.darkMode) {
        document.body.classList.add('dark-mode');
        document.getElementById('darkModeToggle').checked = true;
    }
    
    // Font size
    document.body.className = document.body.className.replace(/font-\w+/g, '');
    document.body.classList.add(`font-${settings.fontSize}`);
    document.getElementById('fontSize').value = settings.fontSize;
    
    // Language
    document.getElementById('language').value = settings.language;
    if (recognition) {
        recognition.lang = settings.language;
    }
    
    // Auto save
    document.getElementById('autoSave').checked = settings.autoSave;
    
    // Volume indicator
    document.getElementById('volumeIndicator').checked = settings.volumeIndicator;
}

function toggleDarkMode() {
    settings.darkMode = !settings.darkMode;
    document.body.classList.toggle('dark-mode');
    saveSettings();
}

function changeFontSize() {
    const select = document.getElementById('fontSize');
    settings.fontSize = select.value;
    document.body.className = document.body.className.replace(/font-\w+/g, '');
    document.body.classList.add(`font-${settings.fontSize}`);
    saveSettings();
}

function changeLanguage() {
    const select = document.getElementById('language');
    settings.language = select.value;
    if (recognition) {
        recognition.lang = settings.language;
    }
    saveSettings();
}

function toggleAutoSave() {
    settings.autoSave = !settings.autoSave;
    saveSettings();
}

function toggleVolumeIndicator() {
    settings.volumeIndicator = !settings.volumeIndicator;
    saveSettings();
}

function clearAllData() {
    if (confirm('Are you sure you want to clear all data? This will delete your history and reset all settings. This cannot be undone.')) {
        localStorage.clear();
        transcriptionHistory = [];
        settings = {
            darkMode: false,
            fontSize: 'medium',
            language: 'en-US',
            autoSave: false,
            volumeIndicator: true
        };
        loadSettings();
        loadHistory();
        updateStatus('All data cleared', false);
    }
}
