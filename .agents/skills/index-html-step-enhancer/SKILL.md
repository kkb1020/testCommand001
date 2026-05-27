---
name: index-html-step-enhancer
description: step 1~5 요청에 따라 index.html의 지정 섹션만 개선하고, 기존 PostToolUse/Stop hook을 통해 검증과 자동 commit이 이어지도록 하는 Skill
---

# index-html-step-enhancer

## 목적

단일 `index.html`에서 사용자가 요청한 step 하나만 개선한다.

이 Skill은 직접 테스트 hook이나 git commit을 실행하지 않는다.  
`index.html` 수정 후 기존 Codex hook 흐름이 자동으로 이어지게 한다.

연결되는 기존 hook 흐름:

1. `index.html` 수정
2. 기존 `PostToolUse` hook이 HTML 기본 검증 수행
3. 필요 시 `playwright_ui_tester`로 실제 브라우저 검증 수행
4. 작업 종료 시 기존 `Stop` hook이 최종 테스트 및 자동 commit 수행

## step 매핑

- step 1: 도시 탐색 / `#cities`
- step 2: 7일 추천 일정 / `#itinerary`
- step 3: 예산 가이드 / `#budget`
- step 4: 꼭 알아야 할 여행 팁 / `#tips`
- step 5: 자주 묻는 질문 / `#faq`

## 실행 규칙

1. repo root와 `index.html` 존재 여부를 확인한다.
2. 사용자가 요청한 step 번호를 확인한다.
3. step 번호에 대응되는 section만 수정한다.
4. 요청되지 않은 section은 수정하지 않는다.
5. 한 번에 여러 step을 수정하지 않는다.
6. 필요한 경우 카드, drawer, modal, accordion, 상세 패널 등 UI 상호작용을 추가한다.
7. 모바일 반응형, 빈 화면 방지, 기본 접근성을 고려한다.
8. 외부 최신 정보가 필요할 때만 `firecrawl-researcher`를 최대 1회 호출한다.
9. 수정 후 `playwright_ui_tester`를 호출해 실제 브라우저 테스트를 수행한다.
10. `playwright_ui_tester`가 PASS이면 수정된 `index.html`을 그대로 둔다.
11. `playwright_ui_tester`가 FAIL이면 한 번만 수정 후 재테스트한다.
12. 재테스트도 FAIL이면 더 이상 수정하지 않고 중단 보고한다.
13. git staging/commit은 직접 수행하지 않는다.
14. 최종 commit은 기존 `Stop` hook이 자동 처리하게 둔다.

## 기존 hook 연결 규칙

이 Skill은 아래 기존 hook이 존재한다고 가정한다.

- `.codex/hooks.json`
- `.codex/hooks/post-html-validation.ps1` 또는 `.codex/hooks/post-html-validation.sh`
- `.codex/hooks/stop-test-and-commit.ps1` 또는 `.codex/hooks/stop-test-and-commit.sh`

연결 원칙:

- `index.html`을 수정하면 `PostToolUse` hook이 자동 검증해야 한다.
- 작업이 끝나면 `Stop` hook이 자동 테스트와 자동 commit을 담당해야 한다.
- Skill은 hook 파일을 수정하지 않는다.
- Skill은 hook을 수동 실행하지 않는다.
- Skill은 hook log를 직접 조작하지 않는다.
- hook이 실행되지 않는 것 같으면 `/hooks` trust 상태 확인이 필요하다고 보고한다.

## Playwright 검증 기준

`playwright_ui_tester`는 다음을 확인해야 한다.

- `index.html` 로드 여부
- body blank 여부
- 수정된 section 렌더링
- 주요 버튼/카드/패널 클릭 동작
- 콘솔 에러
- 네트워크/404 에러
- desktop/mobile 반응형

file URL이 막히면 UI 실패로 보지 말고, repo root에서 임시 localhost static server를 띄워 검증한다.  
localhost 접속 전 서버가 실제 응답하는지 확인한다.  
테스트 종료 후 임시 서버는 종료한다.

## commit 연결 규칙

이 Skill은 직접 commit하지 않는다.

commit은 기존 `Stop` hook이 담당한다.

Skill은 commit이 안전하게 수행되도록 아래를 지킨다.

1. 수정 대상은 `index.html` 하나로 제한한다.
2. `.agents/skills`, `.codex`, `.env`, hook, config 파일은 수정하지 않는다.
3. `git push`를 절대 실행하지 않는다.
4. Playwright 검증 PASS 전에는 작업 완료로 보고하지 않는다.
5. Playwright 검증 FAIL이면 commit이 진행되지 않아야 한다고 보고한다.
6. Stop hook이 자동 commit하지 않으면 `/hooks` trust 또는 hook 활성화 상태를 확인하라고 보고한다.

예상 commit message는 기존 Stop hook 정책을 따른다.  
별도 commit message를 Skill에서 강제하지 않는다.

## 금지사항

- `git push` 금지
- 여러 step 동시 수정 금지
- 요청되지 않은 section 수정 금지
- 무한 재시도 금지
- secret 출력 금지

## 최종 보고 형식

- 실행 step
- 수정 section
- UI 개선 내용
- firecrawl-researcher 호출 여부
- playwright_ui_tester 결과
- PostToolUse hook 연결 여부
- Stop hook 자동 commit 위임 여부
- commit 수행 주체: 기존 Stop hook
- commit hash
- 수정 파일
- 남은 문제
