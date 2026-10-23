/*
 * 让网页自带的「退出应用」按钮在 Pake 壳里生效。
 *
 * 网页当前实现（webpage/src/views/LoginView.vue）：
 *   fetch('http://127.0.0.1:19876/quit', { mode: 'no-cors' })  // 旧 Chrome 壳的本地退出服务
 *   window.close()
 *
 * 在 Pake（Tauri/WebView2）里没有那个本地服务，window.close() 也关不掉主窗口。
 * 这个脚本在页面脚本执行之前注入，把两者都接到 Tauri 的窗口关闭上：
 * Windows 下 hide_on_close 默认关闭，关掉最后一个窗口即退出进程。
 */
(function () {
  var QUIT_HOST = '127.0.0.1:19876';
  var closing = false;

  function currentTauriWindow() {
    var tauri = window.__TAURI__;
    if (!tauri || !tauri.window || typeof tauri.window.getCurrentWindow !== 'function') {
      return null;
    }
    try {
      return tauri.window.getCurrentWindow();
    } catch (error) {
      return null;
    }
  }

  function closeApp() {
    if (closing) return true;
    var current = currentTauriWindow();
    if (!current || typeof current.close !== 'function') return false;
    closing = true;
    try {
      Promise.resolve(current.close()).catch(function () {
        closing = false;
      });
    } catch (error) {
      closing = false;
      return false;
    }
    return true;
  }

  function requestQuit() {
    if (closeApp()) return;
    // __TAURI__ 偶尔还没就绪，稍后重试几次。
    var attempts = 0;
    var timer = setInterval(function () {
      attempts += 1;
      if (closeApp() || attempts >= 20) clearInterval(timer);
    }, 100);
  }

  function urlOf(input) {
    if (typeof input === 'string') return input;
    if (input && typeof input.url === 'string') return input.url;
    return '';
  }

  var nativeFetch = window.fetch;
  if (typeof nativeFetch === 'function') {
    window.fetch = function (input, init) {
      var url = urlOf(input);
      if (url && url.indexOf(QUIT_HOST) !== -1) {
        requestQuit();
        return Promise.resolve(new Response('', { status: 200 }));
      }
      return nativeFetch.apply(this, arguments);
    };
  }

  var nativeClose = window.close;
  window.close = function () {
    if (closeApp()) return;
    try {
      if (typeof nativeClose === 'function') nativeClose.apply(window, arguments);
    } catch (error) {
      /* 主窗口不允许脚本关闭时忽略 */
    }
  };

  // 兜底：网页若改用 __TAURI__ 或自定义事件，也能触发退出。
  window.addEventListener('pake:quit', requestQuit);
  window.pakeQuitApp = requestQuit;
})();
