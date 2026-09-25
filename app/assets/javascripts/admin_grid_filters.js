document.addEventListener("DOMContentLoaded", () => {
  const grid = document.querySelector(".wice-grid-container");
  const apply = document.querySelector(".admin-grid-apply");
  if (!grid || !apply) return;

  const submitFilters = () => {
    const url = new URL(window.location.href);
    for (const key of Array.from(url.searchParams.keys())) {
      if (key.startsWith("grid[f]") || key === "grid[page]") url.searchParams.delete(key);
    }

    grid.querySelectorAll(".wg-filter-row input[name], .wg-filter-row select[name]").forEach((field) => {
      if (!field.disabled && field.value.trim()) url.searchParams.append(field.name, field.value);
    });
    window.location.assign(url);
  };

  apply.addEventListener("click", submitFilters);
  grid.querySelectorAll('.wg-filter-row input[type="text"]').forEach((field) => {
    field.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        submitFilters();
      }
    });
  });
});
