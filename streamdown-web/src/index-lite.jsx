import React from 'react';
import { createRoot } from 'react-dom/client';

// 使用更轻量的 marked 库替代完整的 streamdown
import { marked } from 'marked';

// Global state
let currentMarkdown = '';
let currentIsAnimating = false;
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

// Setup ResizeObserver to monitor content height
function setupHeightObserver() {
    const container = document.getElementById('root');
    if (!container || resizeObserver) return;
    
    resizeObserver = new ResizeObserver((entries) => {
        for (const entry of entries) {
            const height = document.body.scrollHeight;
            sendHeightToSwift(height);
        }
    });
    
    resizeObserver.observe(container);
    
    const mutationObserver = new MutationObserver(() => {
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

// 配置 marked
marked.setOptions({
    gfm: true,
    breaks: false,
    pedantic: false,
});

// 简单的 Markdown 渲染组件
function MarkdownRenderer({ markdown }) {
    const html = React.useMemo(() => {
        try {
            return marked.parse(markdown || '');
        } catch (e) {
            console.error('Markdown parse error:', e);
            return '';
        }
    }, [markdown]);
    
    return React.createElement('div', {
        dangerouslySetInnerHTML: { __html: html }
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
    
    setupHeightObserver();
    render();
    
    setTimeout(() => {
        const height = document.body.scrollHeight;
        sendHeightToSwift(height);
    }, 100);
}

// Render function
function render() {
    if (!root) return;
    
    root.render(
        React.createElement(MarkdownRenderer, { markdown: currentMarkdown })
    );
    
    setTimeout(() => {
        const height = document.body.scrollHeight;
        sendHeightToSwift(height);
    }, 50);
}

// Update function - called from Swift
window.updateMarkdown = function(markdown, isAnimating) {
    currentMarkdown = markdown;
    currentIsAnimating = isAnimating;
    render();
};

// Set initial markdown - called from Swift before init
window.setInitialMarkdown = function(markdown, isAnimating) {
    currentMarkdown = markdown;
    currentIsAnimating = isAnimating;
};

// Get current content height
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
