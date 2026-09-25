document.addEventListener("submit", (event) => {
  const form = event.target;
  if (!(form instanceof HTMLFormElement)) return;

  const submitter = event.submitter;
  const message = submitter?.dataset.confirm || submitter?.dataset.turboConfirm ||
    form.dataset.confirm || form.dataset.turboConfirm;

  if (message && !window.confirm(message)) event.preventDefault();
});
