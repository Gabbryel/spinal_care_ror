import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.enhanceTrixEditor();
  }

  enhanceTrixEditor() {
    const editor = this.element.querySelector("trix-editor");
    if (!editor) return;

    // Add custom button group for text alignment
    this.addAlignmentButtons();

    // Add heading dropdown
    this.addHeadingControls();

    // Add text color controls
    this.addColorControls();

    // Add clear formatting button
    this.addClearFormattingButton();

    // Add horizontal rule button
    this.addHorizontalRuleButton();

    // Add indent controls
    this.addIndentControls();
  }

  addAlignmentButtons() {
    const toolbar = this.element.querySelector("trix-toolbar");
    if (!toolbar) return;

    const alignmentGroup = document.createElement("span");
    alignmentGroup.className = "trix-button-group trix-button-group--alignment";

    const alignments = [
      { value: "left", icon: "⬅", title: "Aliniere stânga" },
      { value: "center", icon: "↔", title: "Aliniere centru" },
      { value: "right", icon: "➡", title: "Aliniere dreapta" },
      { value: "justify", icon: "⬌", title: "Aliniere justify" },
    ];

    alignments.forEach(({ value, icon, title }) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "trix-button trix-button--icon-align-" + value;
      button.dataset.action = "click->richTextEditor#setAlignment";
      button.dataset.alignment = value;
      button.title = title;
      button.innerHTML = `<span class="alignment-icon">${icon}</span>`;
      alignmentGroup.appendChild(button);
    });

    const buttonRow = toolbar.querySelector(".trix-button-row");
    if (buttonRow) {
      buttonRow.appendChild(alignmentGroup);
    }
  }

  addHeadingControls() {
    const toolbar = this.element.querySelector("trix-toolbar");
    if (!toolbar) return;

    const headingGroup = document.createElement("span");
    headingGroup.className = "trix-button-group trix-button-group--headings";

    const headingSelect = document.createElement("select");
    headingSelect.className = "trix-heading-select";
    headingSelect.innerHTML = `
      <option value="">Paragraph</option>
      <option value="heading1">Heading 1</option>
      <option value="sub-heading">Heading 2</option>
      <option value="heading3">Heading 3</option>
    `;
    headingSelect.addEventListener("change", (e) => {
      const value = e.target.value;
      const editor = this.element.querySelector("trix-editor").editor;

      if (value === "") {
        // Remove heading formatting
        editor.deactivateAttribute("heading1");
        editor.deactivateAttribute("sub-heading");
        editor.deactivateAttribute("heading3");
      } else {
        // Apply heading
        editor.activateAttribute(value);
      }

      e.target.value = "";
    });

    headingGroup.appendChild(headingSelect);

    const buttonRow = toolbar.querySelector(".trix-button-row");
    if (buttonRow) {
      buttonRow.insertBefore(headingGroup, buttonRow.firstChild);
    }
  }

  addColorControls() {
    const toolbar = this.element.querySelector("trix-toolbar");
    if (!toolbar) return;

    const colorGroup = document.createElement("span");
    colorGroup.className = "trix-button-group trix-button-group--colors";

    const colorButton = document.createElement("button");
    colorButton.type = "button";
    colorButton.className = "trix-button trix-button--icon-color";
    colorButton.title = "Culoare text";
    colorButton.innerHTML = `<span style="font-weight: bold; color: #3b82f6;">A</span>`;

    const colorPicker = document.createElement("input");
    colorPicker.type = "color";
    colorPicker.className = "trix-color-picker";
    colorPicker.style.display = "none";

    colorButton.addEventListener("click", () => {
      colorPicker.click();
    });

    colorPicker.addEventListener("change", (e) => {
      const color = e.target.value;
      const editor = this.element.querySelector("trix-editor").editor;
      const selection = editor.getSelectedRange();

      if (selection[0] !== selection[1]) {
        const span = document.createElement("span");
        span.style.color = color;
        span.textContent = editor
          .getDocument()
          .toString()
          .substring(selection[0], selection[1]);

        editor.setSelectedRange(selection);
        editor.deleteInDirection("forward");
        editor.insertHTML(span.outerHTML);
      }
    });

    colorGroup.appendChild(colorButton);
    colorGroup.appendChild(colorPicker);

    const buttonRow = toolbar.querySelector(".trix-button-row");
    if (buttonRow) {
      buttonRow.appendChild(colorGroup);
    }
  }

  addClearFormattingButton() {
    const toolbar = this.element.querySelector("trix-toolbar");
    if (!toolbar) return;

    const clearGroup = document.createElement("span");
    clearGroup.className = "trix-button-group trix-button-group--clear";

    const clearButton = document.createElement("button");
    clearButton.type = "button";
    clearButton.className = "trix-button trix-button--icon-clear";
    clearButton.title = "Șterge formatare";
    clearButton.innerHTML = `<span style="font-weight: bold;">T<sub>x</sub></span>`;
    clearButton.addEventListener("click", () => {
      const editor = this.element.querySelector("trix-editor").editor;
      const selection = editor.getSelectedRange();

      if (selection[0] !== selection[1]) {
        const text = editor
          .getDocument()
          .toString()
          .substring(selection[0], selection[1]);
        editor.setSelectedRange(selection);
        editor.deleteInDirection("forward");
        editor.insertString(text);
      }
    });

    clearGroup.appendChild(clearButton);

    const buttonRow = toolbar.querySelector(".trix-button-row");
    if (buttonRow) {
      buttonRow.appendChild(clearGroup);
    }
  }

  addHorizontalRuleButton() {
    const toolbar = this.element.querySelector("trix-toolbar");
    if (!toolbar) return;

    const hrGroup = document.createElement("span");
    hrGroup.className = "trix-button-group trix-button-group--hr";

    const hrButton = document.createElement("button");
    hrButton.type = "button";
    hrButton.className = "trix-button trix-button--icon-hr";
    hrButton.title = "Linie orizontală";
    hrButton.innerHTML = `<span style="font-weight: bold;">―</span>`;
    hrButton.addEventListener("click", () => {
      const editor = this.element.querySelector("trix-editor").editor;
      editor.insertHTML("<hr>");
    });

    hrGroup.appendChild(hrButton);

    const buttonRow = toolbar.querySelector(".trix-button-row");
    if (buttonRow) {
      buttonRow.appendChild(hrGroup);
    }
  }

  addIndentControls() {
    const toolbar = this.element.querySelector("trix-toolbar");
    if (!toolbar) return;

    const indentGroup = document.createElement("span");
    indentGroup.className = "trix-button-group trix-button-group--indent";

    // Decrease indent
    const outdentButton = document.createElement("button");
    outdentButton.type = "button";
    outdentButton.className = "trix-button trix-button--icon-outdent";
    outdentButton.title = "Micșorează indentare";
    outdentButton.innerHTML = `<span>⇤</span>`;
    outdentButton.addEventListener("click", () => {
      const editor = this.element.querySelector("trix-editor").editor;
      editor.decreaseNestingLevel();
    });

    // Increase indent
    const indentButton = document.createElement("button");
    indentButton.type = "button";
    indentButton.className = "trix-button trix-button--icon-indent";
    indentButton.title = "Mărește indentare";
    indentButton.innerHTML = `<span>⇥</span>`;
    indentButton.addEventListener("click", () => {
      const editor = this.element.querySelector("trix-editor").editor;
      editor.increaseNestingLevel();
    });

    indentGroup.appendChild(outdentButton);
    indentGroup.appendChild(indentButton);

    const buttonRow = toolbar.querySelector(".trix-button-row");
    if (buttonRow) {
      buttonRow.appendChild(indentGroup);
    }
  }

  setAlignment(event) {
    const alignment = event.currentTarget.dataset.alignment;
    const editor = this.element.querySelector("trix-editor");

    if (editor) {
      const selection = window.getSelection();
      if (selection.rangeCount > 0) {
        const range = selection.getRangeAt(0);
        const element = range.commonAncestorContainer.parentElement;

        if (element) {
          // Find the closest block element
          let block = element.closest("div, p, h1, h2, blockquote, pre");
          if (!block) {
            block = element;
          }

          block.style.textAlign = alignment;

          // Update button states
          this.element
            .querySelectorAll(".trix-button-group--alignment .trix-button")
            .forEach((btn) => {
              btn.classList.remove("trix-active");
            });
          event.currentTarget.classList.add("trix-active");
        }
      }
    }
  }
}
