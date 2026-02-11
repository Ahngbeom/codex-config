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
`config/repos.txt` 형식:

```text
path|project_type|stage
```

- `project_type`: `app`, `infra`, `db`, `mixed`
- `stage`:
  - `1` 또는 `warn`: Stage 1 (가시화 모드)
  - `2` 또는 `enforce`: Stage 2 (강제 모드)

## 4. 실행 방법
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

## 5. Stage 운영
### Stage 1 (`warn`)
- 규칙 위반을 로그로 노출하지만 CI를 차단하지 않습니다.
- 누락 스크립트/도구 의존성/규칙 위반 패턴을 수집합니다.

### Stage 2 (`enforce`)
- 핵심 위반을 CI 실패로 차단합니다.
- 대표 차단 항목:
  - 앱 저장소에서 `scripts/app-check.sh` 누락
  - Terraform 존재 시 `scripts/iac-plan.sh` 누락
  - 파괴적 SQL 주석 누락 또는 rollback migration 누락

## 6. 프로젝트별 커스텀 스크립트
동기화 시 아래 템플릿이 없으면 자동 생성됩니다.
- `scripts/app-check.sh` (`app`, `mixed`)
- `scripts/iac-plan.sh` (`infra`, `mixed`)
- `scripts/db-check.sh` (`db`, `mixed`)

템플릿은 기본적으로 `exit 1`로 되어 있으므로, Stage 2 전환 전에 프로젝트별 실제 검증 명령으로 반드시 교체해야 합니다.

## 7. 운영 루틴
1. 월 1회 `codex-config` 업데이트 반영
2. Stage 1 실패 로그 분류 및 체크 스크립트 보완
3. 안정화된 저장소부터 Stage 2 전환
4. 브랜치 보호 규칙(required check)으로 `codex-guardrails` 지정

## 8. 롤백
- 잘못 배포된 경우 대상 저장소에서 동기화 커밋을 `revert`
- 긴급 시 workflow의 `enforcement_mode`를 `warn`으로 내려 차단 해제
