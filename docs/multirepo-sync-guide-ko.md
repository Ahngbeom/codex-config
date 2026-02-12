# 멀티레포 Codex 환경 동기화 가이드

## 1. 목적
`codex-config` 저장소의 공통 정책/스킬/가드레일 스크립트를 여러 프로젝트 저장소에 일관되게 배포합니다.

## 2. 동기화 대상
- `AGENTS.md`
- `scripts/check-app.sh`
- `scripts/check-iac.sh`
- `scripts/check-db-migrations.sh`
- `scripts/lib/enforcement.sh`
- `skills/app-dev`, `skills/infra-ops`, `skills/dba-ops`
- `standards/coding`, `standards/security`, `standards/sre`
- `.github/workflows/codex-guardrails.yml` (caller workflow)

## 3. 인벤토리 정의
기본 인벤토리 파일: `config/repos.txt`

형식:

```text
path|project_type|stage
```

- `project_type`: `app`, `infra`, `db`, `mixed`
- `stage`:
  - `1` 또는 `warn`: Stage 1 (가시화 모드)
  - `2` 또는 `enforce`: Stage 2 (강제 모드)

## 4. 공통 실행 방법
### 계획 확인(dry-run)
```bash
scripts/sync-codex-config.sh --plan
```

### 실제 적용
```bash
scripts/sync-codex-config.sh --apply
```

### 특정 저장소만 적용
```bash
scripts/sync-codex-config.sh --apply --repo "/absolute/path/to/repo|app|1"
```

### workflow ref 고정
```bash
scripts/sync-codex-config.sh --apply --config-ref v1
```

## 5. 개인별 Codex CLI 환경 적용 방법
각 개발자가 자신의 로컬 경로에서 Codex CLI를 실행해도 동일한 규칙을 적용하려면, 아래 방식으로 운영합니다.

### 5.1 권장 방식: 중앙 동기화 + 로컬 인벤토리
1. `codex-config` 저장소를 로컬에 클론/업데이트합니다.
2. 개인 인벤토리 파일을 생성합니다.
   - 예시 복사:
   ```bash
   cp config/repos.local.example.txt config/repos.local.txt
   ```
3. `config/repos.local.txt`에 본인 로컬 절대 경로를 입력합니다.
4. 적용 전 미리보기:
   ```bash
   scripts/sync-codex-config.sh --plan --repo-file config/repos.local.txt
   ```
5. 실제 반영:
   ```bash
   scripts/sync-codex-config.sh --apply --repo-file config/repos.local.txt
   ```
6. 각 프로젝트 경로에서 Codex CLI 세션을 시작합니다.
   - 이때 Codex는 해당 레포의 `AGENTS.md`, `skills/`, `scripts/`를 기준으로 동작합니다.

### 5.2 대안 방식: 레포별 수동 적용
- 각 레포에서 직접 파일을 복사/업데이트할 수 있으나, 드리프트가 빠르게 발생합니다.
- 운영 일관성을 위해 권장하지 않습니다.

### 5.3 개인 환경 운영 규칙
- `config/repos.local.txt`는 개인 경로가 포함되므로 Git에 커밋하지 않습니다.
- 로컬 경로 변경 시 `repos.local.txt`만 수정하고 다시 `--plan`/`--apply`를 실행합니다.
- 신규 레포 추가 시 먼저 Stage 1(`warn`)으로 등록하고 안정화 후 Stage 2(`enforce`)로 전환합니다.

## 6. 세션 시작 후 확인 체크리스트
각 레포에서 Codex CLI 세션 시작 후 아래를 확인합니다.

1. `AGENTS.md`가 최신 정책인지 확인
2. 도메인별 체크 스크립트가 존재/실행 가능한지 확인
3. CI workflow가 `codex-guardrails`를 호출하는지 확인
4. 필요 시 로컬에서 검증 실행

```bash
scripts/check-app.sh
scripts/check-iac.sh
scripts/check-db-migrations.sh
```

## 7. Stage 운영
### Stage 1 (`warn`)
- 규칙 위반을 로그로 노출하지만 CI를 차단하지 않습니다.
- 누락 스크립트/도구 의존성/규칙 위반 패턴을 수집합니다.

### Stage 2 (`enforce`)
- 핵심 위반을 CI 실패로 차단합니다.
- 대표 차단 항목:
  - 앱 저장소에서 `scripts/app-check.sh` 누락
  - Terraform 존재 시 `scripts/iac-plan.sh` 누락
  - 파괴적 SQL 주석 누락 또는 rollback migration 누락

## 8. 프로젝트별 커스텀 스크립트
동기화 시 아래 템플릿이 없으면 자동 생성됩니다.
- `scripts/app-check.sh` (`app`, `mixed`)
- `scripts/iac-plan.sh` (`infra`, `mixed`)
- `scripts/db-check.sh` (`db`, `mixed`)

템플릿은 기본적으로 `exit 1`로 되어 있으므로, Stage 2 전환 전에 프로젝트별 실제 검증 명령으로 반드시 교체해야 합니다.

## 9. 운영 루틴
1. 월 1회 `codex-config` 업데이트 반영
2. Stage 1 실패 로그 분류 및 체크 스크립트 보완
3. 안정화된 저장소부터 Stage 2 전환
4. 브랜치 보호 규칙(required check)으로 `codex-guardrails` 지정

## 10. 롤백
- 잘못 배포된 경우 대상 저장소에서 동기화 커밋을 `revert`
- 긴급 시 workflow의 `enforcement_mode`를 `warn`으로 내려 차단 해제
