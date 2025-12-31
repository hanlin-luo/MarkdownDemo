import React from 'react';
import { createRoot } from 'react-dom/client';
import { Streamdown } from 'streamdown';

// Global state
let currentMarkdown = '';
let currentIsAnimating = false;
let autoScrollEnabled = false;
let root = null;
let resizeObserver = null;

// Send height to Swift
function sendHeightToSwift(height) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChanged) {
        window.webkit.messageHandlers.heightChanged.postMessage({
            height: height
        });
    }
}

// Scroll to bottom - request Swift to scroll via UIScrollView
// Note: JavaScript scrolling doesn't work in WKWebView, must use native scroll
function scrollToBottom() {
    if (autoScrollEnabled && currentIsAnimating) {
        if (window.webkit?.messageHandlers?.scrollToBottom) {
            window.webkit.messageHandlers.scrollToBottom.postMessage({});
        }
    }
}

// Setup ResizeObserver to monitor content height
function setupHeightObserver() {
    const container = document.getElementById('root');
    if (!container || resizeObserver) return;
    
    resizeObserver = new ResizeObserver((entries) => {
        for (const entry of entries) {
            // Get the actual scrollHeight of the body for full content height
            const height = document.body.scrollHeight;
            sendHeightToSwift(height);
        }
    });
    
    resizeObserver.observe(container);
    
    // Also observe mutations for dynamic content changes
    const mutationObserver = new MutationObserver(() => {
        // Debounce height updates
        setTimeout(() => {
            const height = document.body.scrollHeight;
            sendHeightToSwift(height);
        }, 50);
    });
    
    mutationObserver.observe(container, {
        childList: true,
        subtree: true,
        characterData: true
    });
}

// Initialize the app
function init() {
    const container = document.getElementById('root');
    if (!container) {
        console.error('Root container not found');
        return;
    }
    
    root = createRoot(container);
    window.pageReady = true;
    
    // Setup height observer
    setupHeightObserver();
    
    // Initial render
    render();
    
    // Send initial height after render
    setTimeout(() => {
        const height = document.body.scrollHeight;
        sendHeightToSwift(height);
    }, 100);
}

// Render function
function render() {
    if (!root) return;
    
    root.render(
        <Streamdown isAnimating={currentIsAnimating}>
            {currentMarkdown}
        </Streamdown>
    );
    
    // Send height after render (with small delay for DOM update)
    setTimeout(() => {
        const height = document.body.scrollHeight;
        sendHeightToSwift(height);
        scrollToBottom();
    }, 50);
}

// Update function - called from Swift
window.updateMarkdown = function(markdown, isAnimating, autoScroll) {
    currentMarkdown = markdown;
    currentIsAnimating = isAnimating;
    if (autoScroll !== undefined) {
        autoScrollEnabled = autoScroll;
    }
    render();
};

// Set initial markdown - called from Swift before init
window.setInitialMarkdown = function(markdown, isAnimating, autoScroll) {
    currentMarkdown = markdown;
    currentIsAnimating = isAnimating;
    if (autoScroll !== undefined) {
        autoScrollEnabled = autoScroll;
    }
};

// Set auto scroll
window.setAutoScroll = function(enabled) {
    autoScrollEnabled = enabled;
};

// Get current content height - can be called from Swift
window.getContentHeight = function() {
    return document.body.scrollHeight;
};

// Export init for manual initialization
window.initStreamdown = init;

// Auto-init when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
