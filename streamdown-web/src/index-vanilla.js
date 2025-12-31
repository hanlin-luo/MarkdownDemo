/**
 * Streamdown Vanilla - 超轻量版 Markdown 渲染器
 * 不使用 React，纯 JavaScript + marked 核心
 * 目标：< 50KB bundle size
 */

import { marked } from 'marked';

// 配置 marked - GFM 模式支持表格、删除线等
marked.setOptions({
    gfm: true,
    breaks: false,
    pedantic: false,
});

// 全局状态
let currentMarkdown = '';
let rootElement = null;
let resizeObserver = null;
let mutationObserver = null;

// 向 Swift 发送高度
function sendHeightToSwift(height) {
    if (window.webkit?.messageHandlers?.heightChanged) {
        window.webkit.messageHandlers.heightChanged.postMessage({ height });
    }
}

// 向 Swift 发送内容就绪通知
function sendContentReady() {
    if (window.webkit?.messageHandlers?.contentReady) {
        window.webkit.messageHandlers.contentReady.postMessage({});
    }
}

// 设置高度观察器
function setupHeightObserver() {
    if (!rootElement || resizeObserver) return;
    
    // ResizeObserver 监听尺寸变化
    resizeObserver = new ResizeObserver(() => {
        sendHeightToSwift(document.body.scrollHeight);
    });
    resizeObserver.observe(rootElement);
    
    // MutationObserver 监听 DOM 变化
    mutationObserver = new MutationObserver(() => {
        // 使用 requestAnimationFrame 合并多次变化
        requestAnimationFrame(() => {
            sendHeightToSwift(document.body.scrollHeight);
        });
    });
    mutationObserver.observe(rootElement, {
        childList: true,
        subtree: true,
        characterData: true
    });
}

// 渲染 Markdown
function render() {
    if (!rootElement) return;
    
    try {
        const html = marked.parse(currentMarkdown || '');
        rootElement.innerHTML = html;
    } catch (e) {
        console.error('Markdown parse error:', e);
        rootElement.innerHTML = '<p style="color:red;">Markdown 解析错误</p>';
    }
    
    // 立即发送高度（不等待观察器）
    requestAnimationFrame(() => {
        sendHeightToSwift(document.body.scrollHeight);
    });
}

// 初始化
function init() {
    rootElement = document.getElementById('root');
    if (!rootElement) {
        console.error('Root container not found');
        return;
    }
    
    window.pageReady = true;
    setupHeightObserver();
    render();
    
    // 初始化完成后发送高度
    requestAnimationFrame(() => {
        sendHeightToSwift(document.body.scrollHeight);
        sendContentReady();
    });
}

// === 暴露给 Swift 的 API ===

// 更新 Markdown 内容
window.updateMarkdown = function(markdown, isAnimating) {
    currentMarkdown = markdown;
    render();
};

// 设置初始 Markdown（在 init 之前调用）
window.setInitialMarkdown = function(markdown, isAnimating) {
    currentMarkdown = markdown;
};

// 获取当前内容高度
window.getContentHeight = function() {
    return document.body.scrollHeight;
};

// 手动初始化入口
window.initStreamdown = init;

// DOM 就绪后自动初始化
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
