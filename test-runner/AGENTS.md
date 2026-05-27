# test-runner 작업 지침

- 이 폴더의 작업은 `.codex/agents/test-runner.toml`에 정의된 `test_runner` agent 기준으로 처리한다.
- 목적은 사용자가 생성하거나 수정한 HTML 또는 Python 파일의 실행 가능 여부와 기본 동작을 빠르게 검증하는 것이다.
- HTML 파일은 구조와 기본 오류를 검사하고, Python 파일은 실행 테스트를 우선 수행한다.
- 실패 시 원인을 짧고 명확하게 보고한다.
- 불필요한 수정은 하지 않는다.
- `~/.codex`와 프로젝트 외부 파일은 수정하지 않는다.
