# html-builder 작업 지침

- 이 폴더의 작업은 `.codex/agents/html-builder.toml`에 정의된 `html_builder` agent 기준으로 처리한다.
- 목표는 단일 `index.html` 페이지를 생성하거나 수정하는 것이다.
- HTML, CSS, JS는 한 파일 안에 작성한다.
- React, Vue, npm, 외부 CDN은 사용하지 않는다.
- CSS는 `<style>` 안에 작성하고, 필요한 경우에만 `<script>`를 사용한다.
- 브라우저에서 바로 열리는 semantic HTML을 유지한다.
- `~/.codex`와 프로젝트 외부 파일은 수정하지 않는다.
