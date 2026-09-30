# 피난길 — 엄마를 찾아서 (Unity 2D)

1950년 6·25 전쟁 피난길에서 엄마와 헤어진 아이가 **엄마가 남긴 단서**를 따라
서울 → 한강 → 피난 열차 → 부산으로 내려가며 엄마를 찾는 2D 탑다운 어드벤처 게임입니다.

## 1. 게임 기획

| 장 | 장면 이름 | 배경 | 모아야 할 단서 (★ = 엄마의 흔적) | 다음으로 가는 조건 |
|---|---|---|---|---|
| 1 | `Ch1_Seoul` | 피난민으로 붐비는 서울 골목 | ★엄마의 흰 손수건, ★옆집 할머니의 이야기, 가족사진 | 손수건 + 할머니 이야기 |
| 2 | `Ch2_HanRiver` | 끊어진 한강 다리, 나루터 | ★찢어진 편지 조각, 뱃사공의 증언(가족사진을 보여줘야 들을 수 있음) | 편지 + 뱃사공 증언 |
| 3 | `Ch3_Train` | 지붕까지 사람이 탄 남행 피난 열차 | ★피난민 명부, 주먹밥 | 피난민 명부 |
| 4 | `Ch4_Busan` | 부산 국제시장, '사람 찾습니다' 벽보 | ★'사람 찾습니다' 벽보 | 벽보 |
| 5 | `Ch5_Yeongdo` | 해질녘 영도다리 | — | ★ 5개를 모두 모았으면 엄마와 재회 |

> 역사 메모: 피난 중 헤어진 가족들이 "영도다리에서 만나자"라고 약속하고,
> 국제시장·부산역 벽에 '사람 찾습니다' 쪽지를 붙였던 실제 이야기를 바탕으로 했습니다.

**조작법**

| 키 | 동작 |
|---|---|
| 방향키 / WASD | 이동 |
| Shift | 달리기 |
| E / Space | 조사하기, 말 걸기, 대화 넘기기 |
| Tab / J | 단서 수첩 열기·닫기 |

## 2. 폴더 구조

```
unity_game/
└── Assets/Scripts/
    ├── Core/        GameManager(단서·저장), IntroPlayer(장 도입 대화)
    ├── Data/        ClueData(단서), DialogueData(대화) — ScriptableObject
    ├── Player/      PlayerController(이동), PlayerInteractor(E로 조사)
    ├── Interaction/ ClueItem(단서 물건), NPC(피난민), SceneExit(다음 장), ReunionTrigger(엄마)
    ├── UI/          DialogueUI(대화창), ClueJournalUI(단서 수첩), TitleMenu(타이틀)
    └── Editor/      StoryDataGenerator(기본 단서·대화 자동 생성 메뉴)
```

## 3. 처음 설정하기

1. **Unity Hub → Add → Add project from disk** 에서 이 `unity_game` 폴더를 선택합니다.
   (Unity 6 권장. 다른 버전이 설치돼 있으면 그 버전으로 열어도 됩니다.)
2. 처음 열 때 TextMeshPro 설치 창이 뜨면 **Import TMP Essentials** 를 누릅니다.
3. 입력 오류가 나면: **Edit → Project Settings → Player → Active Input Handling** 을 `Both` 또는 `Input Manager (Old)` 로 바꿉니다.
4. 상단 메뉴 **피난길 → 기본 스토리 데이터 만들기** 를 누르면 `Assets/StoryData` 에 단서 8개와 대화 5개가 생깁니다.

## 4. 장면 만들기 (1장 예시)

1. **GameManager**: 빈 오브젝트 → `GameManager` 추가 → `All Clues` 에 `StoryData/Clues` 의 단서를 모두 넣기.
   (첫 장면 또는 타이틀 장면에 하나만 두면 됩니다.)
2. **플레이어**: 스프라이트 오브젝트 → `Rigidbody2D`, `CapsuleCollider2D`, `PlayerController`, `PlayerInteractor` 추가.
   머리 위에 "!" 스프라이트를 자식으로 만들어 `Prompt Icon` 에 연결.
3. **UI**: `Canvas` 아래
   - 대화 패널(Image) + 이름 TMP_Text + 본문 TMP_Text → `DialogueUI` 를 Canvas에 붙이고 연결
   - 수첩 패널 + 목록(Vertical Layout Group) + 제목/설명 TMP_Text → `ClueJournalUI` 연결
     (`Entry Prefab` 은 Button 안에 TMP_Text가 들어 있는 프리팹)
4. **단서 물건**: 스프라이트 + `BoxCollider2D`(Is Trigger) + `ClueItem` → `Clue` 에 `Clue_mom_handkerchief`.
5. **NPC**: 스프라이트 + `Collider2D` + `NPC`
   - 옆집 할머니: `Dialogue` = `Dlg_Neighbor`, `Gives Clue` = `Clue_neighbor_testimony`
   - (2장) 뱃사공: `Dialogue` = `Dlg_Boatman`, `Required Clue` = `Clue_family_photo`,
     `Dialogue With Clue` = `Dlg_Boatman_WithPhoto`, `Gives Clue` = `Clue_boatman_testimony`
6. **출구**: 골목 끝에 `BoxCollider2D`(Is Trigger) + `SceneExit`
   → `Next Scene` = `Ch2_HanRiver`, `Required Clues` = 손수건, 할머니 이야기.
7. **도입 대화**: 빈 오브젝트 + `IntroPlayer` → `Dlg_Intro`.
8. **File → Build Profiles(Build Settings)** 에 모든 장면을 순서대로 등록합니다.

마지막 장(`Ch5_Yeongdo`)에는 엄마 캐릭터에 `ReunionTrigger` 를 붙이고
`Reunion Dialogue` = `Dlg_Reunion`, `Required Key Clues` = 5 로 설정합니다.

## 5. 앞으로 추가해 볼 것

- [ ] 도트 그래픽 캐릭터·타일맵 (무료 에셋: Kenney, itch.io)
- [ ] 장별 배경음악과 효과음 (기차 소리, 파도 소리)
- [ ] 2장 한강: 나룻배 타기 미니게임
- [ ] 3장 열차: 칸을 이동하며 명부 찾기 퍼즐
- [ ] 엔딩 장면: 모은 단서를 되돌아보는 회상 화면
