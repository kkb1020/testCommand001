---
name: single-html-page-builder
description: Build or update a single standalone index.html page for one-page web experiences. Use when the user wants a one-file HTML page, landing page, dashboard, or presentation-style page without frameworks, and especially when the work should be done through the html-builder agent with hook-based validation.
---

# Single HTML Page Builder

## Workflow

1. Inspect the current environment first: OS, shell, repository root, `.codex/` structure, existing `index.html`, and existing hooks.
2. Identify the user's topic, purpose, audience, and visual style.
3. If any core point is ambiguous, ask 3 short questions before editing. Give 3 clear choices for each question.
4. Use the `html-builder` agent to create or update only `index.html`.
5. Keep HTML, CSS, and JS in the same file.
6. Use `<style>` for CSS and `<script>` only when needed.
7. Let the configured hooks validate the change:
   - `PostToolUse` checks the HTML structure right after `index.html` changes.
   - `Stop` performs final checks and auto-commit if allowed.
8. Report assumptions when no answer is provided and proceed with a safe default.

## Rules

- Edit only `index.html` unless the user explicitly asks for something else.
- Do not use external CDN assets, npm packages, React, or Vue.
- Prefer semantic HTML, responsive layout, and clear content hierarchy.
- Use the user's supplied data first. If data is missing or uncertain, label it as `예시 데이터` or `미확인`.
- Do not call hooks directly. Rely on the configured Codex hooks.
- Do not use the `test-runner` agent for this workflow; hook-based validation is the source of truth.
- If hooks, the `html-builder` agent, or required repo context are unavailable, stop and report `BLOCKED`.

## Layout Guidance

- Include a navigation bar, hero section, main content sections, a CTA or usage guide, and a footer.
- Use cards, tables, timelines, or comparable layouts when they fit the topic.
- If an image is provided, use it only as a layout reference for spacing, density, and balance.

## Completion

- Confirm the final page opens directly in a browser.
- Mention any assumptions made.
- Report the hook outcome from logs or status when available.
