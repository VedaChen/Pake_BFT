/*
 * 关闭应用内的右键菜单。
 *
 * Pake 会往页面注入一个自定义右键菜单（src-tauri/src/inject/event.js），中文项为：
 *   下载图片 / 复制地址 / 浏览器打开
 * 业务上不需要，这里在捕获阶段拦掉 contextmenu，并兜底隐藏已渲染的菜单节点。
 */
(function () {
  var MENU_ID = 'pake-context-menu';

  function hideMenu() {
    var menu = document.getElementById(MENU_ID);
    if (menu) {
      menu.style.display = 'none';
      menu.setAttribute('hidden', 'hidden');
    }
  }

  // 捕获阶段拦截：不让 Pake 的 bubble 监听器有机会弹出菜单。
  document.addEventListener(
    'contextmenu',
    function (event) {
      event.preventDefault();
      event.stopImmediatePropagation();
      hideMenu();
    },
    true,
  );

  // 兜底样式：即使菜单被插入，也保持不可见。
  function injectStyle() {
    if (document.getElementById('pake-hide-context-menu-style')) return;
    var style = document.createElement('style');
    style.id = 'pake-hide-context-menu-style';
    style.textContent = '#' + MENU_ID + '{display:none !important;visibility:hidden !important;}';
    (document.head || document.documentElement).appendChild(style);
  }

  if (document.head) {
    injectStyle();
  } else {
    document.addEventListener('DOMContentLoaded', injectStyle);
  }

  // 页面是 SPA，菜单节点可能被重新创建，观察一下。
  var observer = new MutationObserver(hideMenu);
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
