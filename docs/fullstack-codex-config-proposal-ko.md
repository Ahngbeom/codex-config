# 풀스택 개발자(웹 애플리케이션/인프라/DBA)를 위한 Codex Configuration 환경 구성 설계 제안

## 1) 목표

웹 애플리케이션 개발, 인프라 운영, 데이터베이스 운영(DBA)까지 담당하는 풀스택 개발자가 **하나의 일관된 Codex 작업 환경**에서 다음을 빠르게 수행하도록 설계합니다.

- 코드 작성/리팩토링/리뷰 자동화
- IaC(Terraform/Helm/Kubernetes) 변경 자동 검증
- 데이터베이스 스키마 변경 안전성 검토
- 운영 대응(런북, 장애 재현, 로그 분석) 보조
- 팀 표준(보안/품질/배포 규칙) 내재화

---

## 2) 핵심 설계 원칙

1. **역할 통합 + 가드레일 강화**
   - 애플리케이션/인프라/DB를 분리된 저장소로 유지하되, Codex 실행 규칙(AGENTS.md + 스킬)은 공통 템플릿으로 통일합니다.

2. **로컬 우선 컨텍스트**
   - 모델이 웹 검색보다 먼저 저장소 내 문서(ADR, runbook, schema, terraform module docs)를 참조하도록 유도합니다.

3. **검증 자동화 우선**
   - “코드 생성 → 정적 검사 → 단위/통합 테스트 → 계획(plan) 리뷰 → 변경 요약”을 Codex 기본 워크플로우로 둡니다.

4. **안전한 변경 기본값(Safe-by-default)**
   - DB 마이그레이션, 프로덕션 인프라 변경, 시크릿 취급 등은 별도 승인/검증 단계를 강제합니다.

---

## 3) 권장 디렉터리/저장소 구조

단일 모노레포 또는 멀티레포 모두 가능하나, Codex 관점에서는 아래와 같은 논리 구조를 권장합니다.

```text
codex-config/
  AGENTS.md
  skills/
    app-dev/
      SKILL.md
      templates/
    infra-ops/
      SKILL.md
      references/
    dba-ops/
      SKILL.md
      checklists/
  standards/
    coding/
    security/
    sre/
  runbooks/
  adr/
  examples/
```

### 운영 팁

- `AGENTS.md`는 전역 정책(보안, 테스트, PR 규칙).
- 도메인별 `SKILL.md`는 실행 절차(예: “Terraform plan 먼저”, “DDL 영향도 체크리스트 먼저”).
- `references/`에는 자주 참조되는 문서를 짧게 요약해 토큰 사용량을 줄입니다.

---

## 4) AGENTS.md 설계 템플릿(요약)

아래 항목을 공통 템플릿으로 권장합니다.

1. **작업 우선순위 규칙**
   - 시스템/개발자/사용자 지시 우선순위 명시
   - 민감 작업(삭제/권한/시크릿) 제한

2. **명령 실행 규칙**
   - `rg` 우선, 대량 탐색 금지
   - 변경 전후 체크 명령 표준화

3. **테스트 정책**
   - 앱: lint + unit + integration
   - 인프라: fmt/validate/plan
   - DB: migration lint + dry-run + rollback 시나리오

4. **커밋/PR 메시지 정책**
   - Conventional Commits
   - 영향 범위, 롤백 방법, 운영 리스크 필수 기재

---

## 5) 스킬(Skill) 체계 제안

풀스택 역할 기준으로 3개 코어 스킬을 두는 구성이 실용적입니다.

## 5.1 app-dev 스킬

**목적**: API/프론트엔드/백엔드 코드 생산성 향상

- 입력: 요구사항, 기존 코드, 테스트 실패 로그
- 절차:
  1) 관련 모듈 식별
  2) 변경 최소화 리팩토링
  3) 테스트 보강
  4) 성능/보안 체크(입력 검증, 인증/인가)
- 출력: 변경 요약 + 테스트 결과 + 리스크

## 5.2 infra-ops 스킬

**목적**: Terraform/K8s/Helm 변경 안전성 강화

- 입력: IaC 변경 요청, 환경(dev/stage/prod)
- 절차:
  1) `fmt/validate`
  2) `plan` 및 파괴적 변경 탐지
  3) 모니터링/알림 영향 분석
  4) 롤백/재적용 전략 제시
- 출력: plan 핵심 diff + 운영 리스크 + 배포 순서

## 5.3 dba-ops 스킬

**목적**: 스키마 변경과 쿼리 튜닝의 안정성 확보

- 입력: DDL/DML 마이그레이션, 슬로우 쿼리
- 절차:
  1) Lock/Index 영향도 분석
  2) 백필/온라인 마이그레이션 여부 판단
  3) 롤백 가능성 검증
  4) 배포 윈도우/트래픽 고려
- 출력: 실행 체크리스트 + 실패 시 복구 단계

---

## 6) 권한/보안 모델 제안

1. **환경 분리**
   - dev/stage/prod 자격증명 분리
   - prod 자격증명은 기본 비노출, 필요 시 단기 토큰

2. **시크릿 처리 원칙**
   - 평문 출력 금지
   - `.env`, 키 파일, 인증서 패턴 자동 마스킹 룰

3. **감사 추적성**
   - Codex 실행 로그와 커밋/PR 연결
   - “누가/언제/무엇을 변경” 메타데이터 보관

---

## 7) CI/CD 연동 아키텍처

Codex가 만든 변경은 아래 파이프라인을 통과해야 합니다.

1. **Pre-commit 단계**
   - lint/format/secret scan

2. **PR 검증 단계**
   - 앱 테스트 + IaC validate/plan + DB migration check

3. **배포 승인 단계**
   - 파괴적 변경(테이블 drop, resource recreate) 자동 플래그

4. **배포 후 검증 단계**
   - SLO/에러율/쿼리 지표 자동 비교

---

## 8) 데이터베이스 변경 가드레일(핵심)

DBA 성격 작업은 특히 아래를 Codex 규칙으로 강제하는 것을 권장합니다.

- 대규모 테이블 DDL은 온라인 가능 여부 사전 확인
- 인덱스 추가 시 쓰기 부하/스토리지 영향 추정
- NOT NULL/타입 변경은 2단계 배포(확장→전환→정리)
- 롤백 SQL 또는 복구 절차 미제공 시 커밋 차단

---

## 9) 관측성(Observability) 내장

Codex가 변경 제안 시 아래를 자동 질문/검증하도록 설계합니다.

- 이 변경을 탐지할 메트릭/로그/트레이스가 있는가?
- 에러 버짓과 SLO에 미치는 영향은?
- 알림 노이즈를 증가시키는가?

권장 스택 예시:

- Metrics: Prometheus/Grafana
- Logs: Loki/ELK
- Tracing: OpenTelemetry + Tempo/Jaeger

---

## 10) 팀 도입 로드맵 (4주)

1주차: 표준 수립
- AGENTS.md 전역 템플릿 확정
- 앱/인프라/DB 체크리스트 정의

2주차: 스킬 파일럿
- app-dev, infra-ops, dba-ops SKILL.md 작성
- 샘플 이슈 10개로 재현 테스트

3주차: CI/CD 통합
- PR 게이트(테스트/plan/migration check) 연결
- 실패 리포트 포맷 통일

4주차: 운영 전개
- 온콜/장애 대응 runbook 연결
- 성과지표(리드타임, 실패율, MTTR) 측정 시작

---

## 11) KPI 제안

- 변경 리드타임(요청→배포)
- 배포 실패율(Change Failure Rate)
- 평균 복구 시간(MTTR)
- 프로덕션 긴급 패치 비율
- 리뷰 사이클 시간(PR open→merge)

---

## 12) 바로 적용 가능한 최소 설정(MVP)

- 전역 `AGENTS.md` 1개
- 도메인 스킬 3개(app/infra/dba) 초안
- CI에서 아래 3종만 먼저 강제
  - 앱 테스트 1개 세트
  - IaC validate/plan
  - DB migration dry-run

이 MVP만으로도 “무분별한 자동 생성”이 아니라 “검증 가능한 자동화”로 전환할 수 있습니다.
