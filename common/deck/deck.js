/* Shared deck bootstrap for all demo decks.
 *
 * A deck's index.html loads reveal.js, this file and ../config.js, sets
 * <body data-deck-title="..." data-session="demo1-fundamentals"> and calls
 * Deck.init().
 *
 * Conventions inside a deck:
 *   <section class="no-chrome">                 title/closing slide: no footer, hat or rule
 *   <div class="shot" data-src="images/x.png" data-caption="...">
 *                                                console screenshot; shows a
 *                                                placeholder until the file exists
 *   <a class="followup-link"></a>, <div class="qr"></div>
 *                                                filled from config.js (follow-up app URL)
 *   <aside class="notes">...</aside>             speaker notes (press "s")
 *   <use href="#i-pod" .../>                     diagram icons from common/icons.svg
 */
(function () {
  function chrome(title) {
    const add = (cls, html) => {
      const el = document.createElement("div");
      el.className = cls;
      if (html) el.innerHTML = html;
      document.body.appendChild(el);
      return el;
    };
    add("deck-rule");
    add("deck-footer").textContent = title;
    const hat = document.createElement("img");
    hat.className = "deck-hat";
    hat.src = "images/redhat-hat.svg";
    hat.alt = "";
    document.body.appendChild(hat);
  }

  function screenshots() {
    document.querySelectorAll(".shot").forEach((el) => {
      const src = el.dataset.src;
      const caption = el.dataset.caption || "";
      const img = new Image();
      img.className = "shot";
      img.alt = caption;
      img.onload = () => { el.replaceChildren(img); };
      img.onerror = () => {
        el.innerHTML =
          '<div class="shot-missing">Screenshot not captured yet: ' + caption +
          "<code>" + src + "</code></div>";
      };
      img.src = src;
    });
  }

  function followups(session) {
    const cfg = window.DECK_CONFIG || {};
    if (!cfg.followupUrl) return;
    const url = cfg.followupUrl.replace(/\/$/, "") + "/?session=" + encodeURIComponent(session);
    document.querySelectorAll("a.followup-link").forEach((a) => {
      a.href = url;
      a.target = "_blank";
      a.textContent = url.replace(/^https?:\/\//, "");
    });
    if (window.qrcode) {
      document.querySelectorAll(".qr").forEach((el) => {
        const qr = window.qrcode(0, "M");
        qr.addData(url);
        qr.make();
        el.innerHTML = qr.createSvgTag({ cellSize: 6, margin: 0, scalable: true });
      });
    }
  }

  // Shared diagram icons (common/icons.svg): injected once so every inline
  // diagram can reference them with <use href="#i-pod" .../>
  function icons() {
    return fetch("../common/icons.svg")
      .then((r) => (r.ok ? r.text() : ""))
      .then((svg) => {
        const holder = document.createElement("div");
        holder.style.cssText = "position:absolute;width:0;height:0;overflow:hidden";
        holder.setAttribute("aria-hidden", "true");
        holder.innerHTML = svg;
        document.body.prepend(holder);
      })
      .catch(() => {});
  }

  window.Deck = {
    init() {
      const title = document.body.dataset.deckTitle || document.title;
      const session = document.body.dataset.session || "";
      chrome(title);
      screenshots();
      followups(session);
      return icons().then(() => start());
    },
  };

  function start() {
      Reveal.initialize({
        width: 1920,
        height: 1080,
        margin: 0.04,
        hash: true,
        slideNumber: "c/t",
        showSlideNumber: "all",
        transition: "fade",
        backgroundTransition: "none",
        center: true,
        plugins: [RevealNotes, RevealHighlight],
      });
      // Title/closing slides hide the shared chrome
      const sync = () =>
        document.body.classList.toggle(
          "no-chrome", !!Reveal.getCurrentSlide().closest("section.no-chrome"));
      Reveal.on("ready", sync);
      Reveal.on("slidechanged", sync);
  }
})();
