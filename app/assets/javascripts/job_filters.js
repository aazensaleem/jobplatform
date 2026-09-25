document.addEventListener("change", (event) => {
  const checkbox = event.target;
  if (!(checkbox instanceof HTMLInputElement) || !checkbox.matches("input[data-submit-on-change]")) return;

  checkbox.form?.requestSubmit();
});
