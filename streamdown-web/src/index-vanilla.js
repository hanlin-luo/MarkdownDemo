/**
 * Streamdown Vanilla - 轻量版 Markdown 渲染器
 * 不使用 React，纯 JavaScript + marked + highlight.js
 * 目标：< 100KB bundle size (with syntax highlighting)
 */

import { marked } from 'marked';
import hljs from 'highlight.js/lib/core';

// 只导入常用语言以减小 bundle 大小
import javascript from 'highlight.js/lib/languages/javascript';
import typescript from 'highlight.js/lib/languages/typescript';
import python from 'highlight.js/lib/languages/python';
import swift from 'highlight.js/lib/languages/swift';
import java from 'highlight.js/lib/languages/java';
import kotlin from 'highlight.js/lib/languages/kotlin';
import cpp from 'highlight.js/lib/languages/cpp';
import c from 'highlight.js/lib/languages/c';
import csharp from 'highlight.js/lib/languages/csharp';
import go from 'highlight.js/lib/languages/go';
import rust from 'highlight.js/lib/languages/rust';
import ruby from 'highlight.js/lib/languages/ruby';
import php from 'highlight.js/lib/languages/php';
import sql from 'highlight.js/lib/languages/sql';
import bash from 'highlight.js/lib/languages/bash';
import shell from 'highlight.js/lib/languages/shell';
import json from 'highlight.js/lib/languages/json';
import xml from 'highlight.js/lib/languages/xml';
import css from 'highlight.js/lib/languages/css';
import scss from 'highlight.js/lib/languages/scss';
import yaml from 'highlight.js/lib/languages/yaml';
import markdown from 'highlight.js/lib/languages/markdown';
import diff from 'highlight.js/lib/languages/diff';
import dockerfile from 'highlight.js/lib/languages/dockerfile';
import nginx from 'highlight.js/lib/languages/nginx';
import objectivec from 'highlight.js/lib/languages/objectivec';

// 注册语言
hljs.registerLanguage('javascript', javascript);
hljs.registerLanguage('js', javascript);
hljs.registerLanguage('typescript', typescript);
hljs.registerLanguage('ts', typescript);
hljs.registerLanguage('python', python);
hljs.registerLanguage('py', python);
hljs.registerLanguage('swift', swift);
hljs.registerLanguage('java', java);
hljs.registerLanguage('kotlin', kotlin);
hljs.registerLanguage('kt', kotlin);
hljs.registerLanguage('cpp', cpp);
hljs.registerLanguage('c++', cpp);
hljs.registerLanguage('c', c);
hljs.registerLanguage('csharp', csharp);
hljs.registerLanguage('cs', csharp);
hljs.registerLanguage('go', go);
hljs.registerLanguage('golang', go);
hljs.registerLanguage('rust', rust);
hljs.registerLanguage('rs', rust);
hljs.registerLanguage('ruby', ruby);
hljs.registerLanguage('rb', ruby);
hljs.registerLanguage('php', php);
hljs.registerLanguage('sql', sql);
hljs.registerLanguage('bash', bash);
hljs.registerLanguage('sh', bash);
hljs.registerLanguage('zsh', bash);
hljs.registerLanguage('shell', shell);
hljs.registerLanguage('json', json);
hljs.registerLanguage('xml', xml);
hljs.registerLanguage('html', xml);
hljs.registerLanguage('css', css);
hljs.registerLanguage('scss', scss);
hljs.registerLanguage('sass', scss);
hljs.registerLanguage('yaml', yaml);
hljs.registerLanguage('yml', yaml);
hljs.registerLanguage('markdown', markdown);
hljs.registerLanguage('md', markdown);
hljs.registerLanguage('diff', diff);
hljs.registerLanguage('dockerfile', dockerfile);
hljs.registerLanguage('docker', dockerfile);
hljs.registerLanguage('nginx', nginx);
hljs.registerLanguage('objectivec', objectivec);
hljs.registerLanguage('objc', objectivec);
hljs.registerLanguage('objective-c', objectivec);

// 自定义 marked 的代码块渲染器
const renderer = new marked.Renderer();

renderer.code = function(code, language) {
    // 处理 marked v5+ 的对象参数格式
    let codeText = code;
    let lang = language;
    
    if (typeof code === 'object' && code !== null) {
        codeText = code.text || '';
        lang = code.lang || '';
    }
    
    // 清理语言标识
    lang = (lang || '').toLowerCase().trim();
    
    let highlighted;
    if (lang && hljs.getLanguage(lang)) {
        try {
            highlighted = hljs.highlight(codeText, { language: lang }).value;
        } catch (e) {
            console.warn('Highlight error for language:', lang, e);
            highlighted = escapeHtml(codeText);
        }
    } else {
        // 尝试自动检测语言
        try {
            const result = hljs.highlightAuto(codeText);
            highlighted = result.value;
        } catch (e) {
            highlighted = escapeHtml(codeText);
        }
    }
    
    const langClass = lang ? ` language-${lang}` : '';
    return `<pre><code class="hljs${langClass}">${highlighted}</code></pre>`;
};

// HTML 转义函数
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// 配置 marked
marked.setOptions({
    gfm: true,
    breaks: false,
    pedantic: false,
    renderer: renderer
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
