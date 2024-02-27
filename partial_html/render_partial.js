class RenderPartial extends HTMLElement {
  constructor() {
    super();

    const src = this.getAttribute("src");
    if (!src) return; // src is required

    const iframe = document.createElement("iframe");
    iframe.src = src;
    iframe.setAttribute("hidden", "hidden");

    const onload = `.replaceWith(
      ...contentDocument.head.childNodes,
      ...contentDocument.body.childNodes)`;

    if (this.hasAttribute("capsule")) {
      iframe.setAttribute("onload", `this${onload}`);
      this.attachShadow({ mode: "open" });
      this.shadowRoot.append(iframe);
    } else {
      iframe.setAttribute("onload", `parentNode${onload}`);
      this.append(iframe);
    }
  }
}
customElements.define("render-partial", RenderPartial);
