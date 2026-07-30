# 논문 삽입용 ERD (영문) — 안내

ERD는 이제 **SVG 파일로 저장소에 있습니다.** 이 문서에 있던 Mermaid 사본은
같은 스키마를 서술한 문서가 셋이 되면서 계속 어긋났기 때문에 제거했습니다.

## 어디를 보면 되는가

| 필요한 것 | 파일 |
|---|---|
| 논문에 넣을 ERD 그림 | [`erd-en.svg`](erd-en.svg) |
| 스키마 전체 명세 (한국어, 정본) | [`erd.md`](erd.md) |
| 논문 3-6절 원고 | [`thesis-db-section.md`](thesis-db-section.md) |
| 실행 가능한 DDL | [`../supabase/schema.sql`](../supabase/schema.sql) |

## 논문에 넣는 방법

Word에서 **삽입 → 그림 → 이 디바이스** → `erd-en.svg` 선택.
`.svg`를 직접 넣으면 벡터로 유지되어 확대해도 깨지지 않습니다.
중간에 PNG로 변환하면 인쇄 해상도가 떨어집니다.

권장 캡션 — 〈그림 9〉/〈그림 10〉이 시스템 구성도의 국문·영문 쌍이므로 그 다음 번호:

```
〈그림 11〉 BabySense 데이터베이스 ERD (BabySense Database ERD)
```

ERD는 테이블명과 컬럼명이 이미 영문이므로 국문 버전을 따로 만들지 않고
캡션에만 병기합니다.

## 시스템 구성도

같은 방식으로 교체용 SVG가 준비되어 있습니다.

| 대상 | 파일 |
|---|---|
| 〈그림 9〉 시스템 구성도 (국문) | [`system-architecture-kr.svg`](system-architecture-kr.svg) |
| 〈그림 10〉 System Architecture (영문) | [`system-architecture-en.svg`](system-architecture-en.svg) |

기존 그림에 **오른쪽 클릭 → 그림 바꾸기**로 교체하면 크기와 위치가 유지됩니다.
