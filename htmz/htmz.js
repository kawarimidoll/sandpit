const frames = [...document.querySelectorAll('[id^="hz-"]')].map((e) => {
  const { id, dataset: { src = "" } } = e;
  const htmz = `document.getElementById('${id}')` +
    "?.replaceChildren(...contentDocument.body.childNodes)";
  return `<iframe hidden name="#${id}" onload="${htmz}" src="${src}"></iframe>`;
}).join("");
document.body.insertAdjacentHTML("beforeend", `<div>${frames}</div>`);
