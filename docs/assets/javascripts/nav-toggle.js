/* Show or hide the left navigation on wide screens, and remember the choice across pages. */
(function () {
  "use strict";

  var KEY = "avd-nav-hidden";
  var root = document.documentElement;
  var FRAME = "M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Zm0 2v12h16V6H4Z";
  var ICON_SHOWN = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><path fill-rule="evenodd" d="' + FRAME + 'm1 1h4v10H5V7Z"/></svg>';
  var ICON_HIDDEN = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true"><path fill-rule="evenodd" d="' + FRAME + 'm4 0h1.5v12H8V6Z"/></svg>';

  function storedHidden() {
    try {
      return window.localStorage.getItem(KEY) === "1";
    } catch (error) {
      return false;
    }
  }

  function render(hidden) {
    root.classList.toggle("avd-nav-hidden", hidden);
    var button = document.querySelector(".avd-nav-toggle");
    if (!button) {
      return;
    }
    var label = hidden ? "Show navigation" : "Hide navigation";
    button.setAttribute("aria-label", label);
    button.setAttribute("aria-pressed", hidden ? "true" : "false");
    button.title = label;
    button.innerHTML = hidden ? ICON_HIDDEN : ICON_SHOWN;
  }

  function addButton() {
    if (document.querySelector(".avd-nav-toggle")) {
      return;
    }
    var title = document.querySelector(".md-header__title");
    if (!title || !title.parentNode) {
      return;
    }
    var button = document.createElement("button");
    button.type = "button";
    button.className = "md-header__button md-icon avd-nav-toggle";
    button.addEventListener("click", function () {
      var hidden = !root.classList.contains("avd-nav-hidden");
      try {
        window.localStorage.setItem(KEY, hidden ? "1" : "0");
      } catch (error) {
        // Storage can be blocked. The toggle still works on this page.
      }
      render(hidden);
    });
    title.parentNode.insertBefore(button, title);
  }

  function init() {
    addButton();
    render(storedHidden());
  }

  // With instant navigation, Material emits document$ after every page load.
  if (window.document$ && typeof window.document$.subscribe === "function") {
    window.document$.subscribe(init);
  } else if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
