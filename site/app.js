"use strict";

const cards = [...document.querySelectorAll("[data-skill]")];
const filters = [...document.querySelectorAll("[data-filter]")];
const search = document.querySelector("#skill-search");
let category = "all";

function filterSkills() {
  const query = search.value.trim().toLocaleLowerCase();
  let count = 0;
  for (const card of cards) {
    const matches = (category === "all" || card.dataset.category === category)
      && card.textContent.toLocaleLowerCase().includes(query);
    card.hidden = !matches;
    if (matches) count += 1;
  }
  for (const button of filters) {
    const active = button.dataset.filter === category;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", String(active));
  }
  document.querySelector("#result-count").textContent = `${count} OF ${cards.length} SKILLS`;
  document.querySelector("#empty-state").hidden = count !== 0;
}

for (const button of filters) {
  button.addEventListener("click", () => {
    category = button.dataset.filter;
    filterSkills();
  });
}
search.addEventListener("input", filterSkills);
document.querySelector("#reset-search").addEventListener("click", () => {
  category = "all";
  search.value = "";
  filterSkills();
  search.focus();
});
document.querySelector("#catalog-toolbar").hidden = false;

const target = document.querySelector("#install-target");
const preview = document.querySelector("#preview-install");
const projectRoot = document.querySelector("#project-root");
const command = document.querySelector("#install-command");
const copyStatus = document.querySelector("#copy-status");
const copyButton = document.querySelector("#copy-command");
let commandRevision = 0;

function updateCommand() {
  const scope = document.querySelector('input[name="scope"]:checked').value;
  const project = scope === "Project";
  document.querySelector("#project-field").hidden = !project;
  // Single-quoted PowerShell strings keep spaces and metacharacters literal.
  const path = projectRoot.value.replace(/[\r\n]/g, "").replaceAll("'", "''");
  let install = `pwsh -NoProfile -File ./scripts/install-skills.ps1 -Target ${target.value} -Scope ${scope}`;
  if (project) install += ` -ProjectRoot '${path}'`;
  if (preview.checked) install += " -WhatIf";
  command.textContent = `git clone https://github.com/vannt-dev/ai-engineering-skills.git\ncd ai-engineering-skills\n${install}`;
  copyStatus.textContent = "";
  commandRevision += 1;
}

document.querySelector("#install-controls").addEventListener("input", updateCommand);
document.querySelector("#install-controls").hidden = false;
copyButton.hidden = false;
copyButton.addEventListener("click", async () => {
  const revision = commandRevision;
  try {
    await navigator.clipboard.writeText(command.textContent);
    if (revision === commandRevision) copyStatus.textContent = "Commands copied. Paste into your terminal.";
  } catch {
    const selection = window.getSelection();
    if (selection) {
      const range = document.createRange();
      range.selectNodeContents(command);
      selection.removeAllRanges();
      selection.addRange(range);
    }
    copyStatus.textContent = "Copy is unavailable here. Select the commands and copy them manually.";
  }
});
updateCommand();
