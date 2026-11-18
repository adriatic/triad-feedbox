// A small stand-in for the design tool's runtime ("support.js", which is not
// in the repository), so that the six designs in design/*.dc.html can be drawn
// in a browser for the side-by-side images (e2e/screenshots.spec.ts, task F5).
// It understands what the six files use: {{value}} in text and attributes,
// <sc-for list as>, <sc-if value>, on* event attributes, <helmet>, and the
// Component class in <script type="text/x-dc">. Props come from data-props
// defaults, overridden by the page address (?dark=1).
(function () {
  class DCLogic {
    constructor(props) {
      this.props = props;
      this.state = {};
    }
    setState(patch) {
      Object.assign(this.state, patch);
      render();
    }
  }
  window.DCLogic = DCLogic;

  const WHOLE = /^\s*\{\{\s*([^}]+?)\s*\}\}\s*$/;
  const PART = /\{\{\s*([^}]+?)\s*\}\}/g;
  let component;
  let template;
  let host;

  function lookup(scope, path) {
    return path.split(".").reduce((o, k) => (o == null ? undefined : o[k]), scope);
  }

  function value(text, scope) {
    const m = WHOLE.exec(text);
    if (m) return lookup(scope, m[1]);
    return text.replace(PART, (_, p) => {
      const v = lookup(scope, p);
      return v == null ? "" : String(v);
    });
  }

  function build(node, scope, parent) {
    if (node.nodeType === Node.TEXT_NODE) {
      parent.appendChild(document.createTextNode(String(value(node.textContent, scope) ?? "")));
      return;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return;
    const tag = node.localName;
    if (tag === "helmet") return;
    if (tag === "sc-for") {
      const list = value(node.getAttribute("list"), scope) || [];
      const as = node.getAttribute("as");
      for (const item of list) {
        const inner = Object.create(scope);
        inner[as] = item;
        for (const child of node.childNodes) build(child, inner, parent);
      }
      return;
    }
    if (tag === "sc-if") {
      if (value(node.getAttribute("value"), scope)) for (const child of node.childNodes) build(child, scope, parent);
      return;
    }
    const el = document.createElementNS(node.namespaceURI, node.localName);
    for (const attr of node.attributes) {
      const v = value(attr.value, scope);
      if (attr.name.startsWith("on")) {
        if (typeof v === "function") el.addEventListener(attr.name.slice(2).toLowerCase(), v);
        continue;
      }
      if (v === false || v == null) {
        if (attr.name.startsWith("aria-")) el.setAttribute(attr.name, "false");
        continue;
      }
      el.setAttribute(attr.name, String(v));
      if (attr.name === "value" && "value" in el) el.value = String(v);
    }
    for (const child of node.childNodes) build(child, scope, el);
    parent.appendChild(el);
  }

  function render() {
    const vals = component.renderVals();
    host.replaceChildren();
    for (const child of template.childNodes) build(child, vals, host);
  }

  document.addEventListener("DOMContentLoaded", () => {
    const xdc = document.querySelector("x-dc");
    const script = document.querySelector("script[data-dc-script]");
    const helmet = xdc.querySelector("helmet");
    if (helmet) for (const child of [...helmet.childNodes]) document.head.appendChild(child);
    template = xdc;
    host = document.createElement("div");
    xdc.replaceWith(host);

    const defaults = JSON.parse(script.dataset.props || "{}");
    const props = {};
    for (const [k, spec] of Object.entries(defaults)) if (!k.startsWith("$")) props[k] = spec.default;
    const query = new URLSearchParams(location.search);
    if (query.has("dark")) props.dark = query.get("dark") === "1";
    const Component = new Function("DCLogic", `${script.textContent}\nreturn Component;`)(DCLogic);
    component = new Component(props);
    render();
    document.documentElement.dataset.rendered = "1";
  });
})();
