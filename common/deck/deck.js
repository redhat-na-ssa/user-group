/* Shared deck bootstrap for all demo decks.
 *
 * A deck's index.html loads reveal.js, ../lib/qrcode.js and this file, sets
 * <body data-deck-title="..."> and calls Deck.init().
 *
 * Conventions inside a deck:
 *   <section class="no-chrome">                 title/closing slide: no footer, hat or rule
 *   <div class="shot" data-src="images/x.webp" data-caption="...">
 *                                                console screenshot; shows a
 *                                                placeholder until the file exists
 *   <div class="qr" data-url="https://..."></div>
 *                                                QR code for the URL (Q&A: the deck's public URL)
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

  function qrcodes() {
    if (!window.qrcode) return;
    document.querySelectorAll(".qr[data-url]").forEach((el) => {
      const qr = window.qrcode(0, "M");
      qr.addData(el.dataset.url);
      qr.make();
      el.innerHTML = qr.createSvgTag({ cellSize: 6, margin: 0, scalable: true });
    });
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

  // Load the Red Hat fonts before reveal.js lays out the first slide, so the
  // text doesn't jump from the fallback font to the real one (the deck stays
  // hidden until reveal adds .ready - see theme.css). Never wait more than 2s.
  function fonts() {
    if (!document.fonts) return Promise.resolve();
    const faces = ['400 1em "Red Hat Text"', '500 1em "Red Hat Text"',
                   '400 1em "Red Hat Display"', '500 1em "Red Hat Display"',
                   '400 1em "Red Hat Mono"'];
    const loaded = Promise.all(faces.map((f) => document.fonts.load(f))).catch(() => {});
    return Promise.race([loaded, new Promise((r) => setTimeout(r, 2000))]);
  }

  window.Deck = {
    init() {
      const title = document.body.dataset.deckTitle || document.title;
      chrome(title);
      screenshots();
      qrcodes();
      return Promise.all([icons(), fonts()]).then(() => start());
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
      // T: from a down slide (backup screenshot, concept) back to the top
      // of its stack in one press; listed in the "?" help overlay
      Reveal.addKeyBinding(
        { keyCode: 84, key: "T", description: "Top of this vertical stack" },
        () => Reveal.slide(Reveal.getIndices().h, 0));
  }
})();
