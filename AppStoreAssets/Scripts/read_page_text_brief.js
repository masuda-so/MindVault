(() => {
  return JSON.stringify({
    location: location.href,
    title: document.title,
    text: document.body.innerText.slice(0, 6000)
  }, null, 2);
})();
