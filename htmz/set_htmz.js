document.head.insertAdjacentHTML('beforeend', '<base target=htmz>')
document.body.insertAdjacentHTML('beforeend', '<iframe hidden name=htmz onload="setTimeout(()=>document.querySelector(contentWindow.location.hash||null)?.replaceWith(...contentDocument.body.childNodes))"></iframe>')
