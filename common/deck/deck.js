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

  window.Deck = {
    init() {
      const title = document.body.dataset.deckTitle || document.title;
      const session = document.body.dataset.session || "";
      chrome(title);
      screenshots();
      followups(session);
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
    },
  };
})();
