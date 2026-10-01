# 피난길 — 엄마를 찾아서 (Unity 2D)

1950년 12월 장단역에서 피난 중 엄마와 헤어진 아이가 **엄마가 남긴 단서**를 따라
1953년 문산 자유의 다리를 거쳐 임진강 가(지금의 임진각)에서 엄마를 다시 만나는 2D 탑다운 어드벤처 게임입니다.

## 1. 게임 기획

| 장 | 장면 이름 | 때와 곳 | 모아야 할 단서 (★ = 엄마의 흔적) | 다음으로 가는 조건 |
|---|---|---|---|---|
| 1 | `Ch1_Jangdan` | 1950년 12월, 피난 열차가 멈춰 선 장단역 | ★엄마의 흰 손수건, ★역무원의 이야기, 가족사진 | 손수건 + 역무원 이야기 |
| 2 | `Ch2_FreedomBridge` | 1953년 8월, 포로들이 돌아오는 문산 자유의 다리 | ★문산 피난민촌 명부, 헌병의 증언(가족사진을 보여줘야 들을 수 있음), ★다리 난간의 쪽지 | 명부 + 쪽지 |
| 3 | `Ch3_Imjingak` | 1953년, 해질녘 임진강 가 (훗날 임진각이 세워진 곳) | — | ★ 4개를 모두 모았으면 엄마와 재회 → 엔딩 |

> 역사 메모
> - **장단역**: 1950년 12월 31일 장단역에서 멈춰 선 증기기관차는 '철마는 달리고 싶다'의 상징이 되었고, 지금은 임진각에 전시되어 있습니다.
> - 1·4 후퇴 무렵 피난민들은 얼어붙은 임진강을 걸어서 건너 남쪽으로 내려왔습니다.
> - **자유의 다리**: 1953년 휴전 뒤 포로 교환 때 국군 포로들이 "자유 만세"를 외치며 건너온 다리입니다.
> - **임진각**: 1972년 세워졌고, 고향에 가지 못한 실향민들이 명절마다 북녘을 향해 절하는 망배단이 있습니다.

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
4. 상단 메뉴 **피난길 → 기본 스토리 데이터 만들기** 를 누르면 `Assets/StoryData` 에 단서 6개와 대화 6개가 생깁니다.

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
   - 역무원: `Dialogue` = `Dlg_Stationmaster`, `Gives Clue` = `Clue_stationmaster_testimony`
   - (2장) 헌병: `Dialogue` = `Dlg_Soldier`, `Required Clue` = `Clue_family_photo`,
     `Dialogue With Clue` = `Dlg_Soldier_WithPhoto`, `Gives Clue` = `Clue_soldier_testimony`
6. **출구**: 승강장 끝(임진강 쪽)에 `BoxCollider2D`(Is Trigger) + `SceneExit`
   → `Next Scene` = `Ch2_FreedomBridge`, `Required Clues` = 손수건, 역무원 이야기.
7. **도입 대화**: 빈 오브젝트 + `IntroPlayer` → `Dlg_Intro_Jangdan` (2장은 `Dlg_Intro_FreedomBridge`).
8. **File → Build Profiles(Build Settings)** 에 모든 장면을 순서대로 등록합니다.

마지막 장(`Ch3_Imjingak`)에는 엄마 캐릭터에 `ReunionTrigger` 를 붙이고
`Reunion Dialogue` = `Dlg_Reunion`, `Required Key Clues` = 4 로 설정합니다.

## 5. 앞으로 추가해 볼 것

- [ ] 도트 그래픽 캐릭터·타일맵 (무료 에셋: Kenney, itch.io)
- [ ] 장별 배경음악과 효과음 (기차 소리, 파도 소리)
- [ ] 1장 → 2장 사이: 얼어붙은 임진강을 건너는 미니게임 (얼음 깨지는 곳 피하기)
- [ ] 2장 자유의 다리: 철조망의 쪽지들 사이에서 엄마 글씨 찾기 퍼즐
- [ ] 엔딩 장면: 모은 단서를 되돌아보는 회상 화면
