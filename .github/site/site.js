document.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-copy-target]");
  if (!button) return;
  const content = document.getElementById(button.dataset.copyTarget);
  if (!content) return;
  try {
    await navigator.clipboard.writeText(content.textContent);
    const previous = button.title;
    button.title = "Copied";
    setTimeout(() => { button.title = previous; }, 1500);
  } catch (error) {
    console.error("Unable to copy repository commands", error);
  }
});
